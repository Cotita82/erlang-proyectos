%% Monitor de nodos: se entera de quien entra y sale del cluster, recalcula
%% quorum y lider, registra eventos y reintenta conectar a los ausentes.
%% Esto es lo que hace que los nodos "se unan y salgan sin intervencion manual".
%%
%% Distinguir "muerto" de "lento": este modulo no lo adivina. Se apoya en el
%% deteccion de Erlang (net_ticktime, 60 s por omision), que declara caido a un
%% nodo que no responde a los latidos. Hasta entonces el nodo sigue contando como
%% conectado. Esa ventana de tiempo es parte del compromiso que se documenta.
-module(p15_cluster_de_2_3_nodos_monitor).
-behaviour(gen_server).

-export([start_link/0, estado/0, miembros/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-define(REINTENTO_MS, 5000).

start_link() ->
  gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% Foto del cluster desde el punto de vista de ESTE nodo.
estado() ->
  gen_server:call(?MODULE, estado).

miembros() ->
  gen_server:call(?MODULE, miembros).

init([]) ->
  %% Los miembros salen del env `nodos`; si no esta, el cluster es solo este nodo
  %% (asi el proyecto sigue arrancando sin distribucion, por ejemplo en eunit).
  Miembros = lists:usort(application:get_env(p15_cluster_de_2_3_nodos, nodos, [node()])),
  %% Primero se pide el aviso y despues se lee nodes(): asi no se pierde ningun
  %% nodo que se conecte justo entre las dos operaciones.
  _ = net_kernel:monitor_nodes(true),
  Conectados = lists:usort([node() | nodes()]),
  erlang:send_after(?REINTENTO_MS, self(), reintentar),
  {ok, recalcular(#{miembros => Miembros, conectados => Conectados, lider => sin_lider})}.

handle_call(estado, _From, State) ->
  {reply, foto(State), State};
handle_call(miembros, _From, #{miembros := Miembros} = State) ->
  {reply, Miembros, State}.

handle_cast(_Msg, State) ->
  {noreply, State}.

handle_info({nodeup, Nodo}, #{miembros := Miembros, conectados := Conectados} = State) ->
  case lists:member(Nodo, Miembros) of
    true ->
      p15_cluster_de_2_3_nodos_eventos:registrar(nodo_reconectado, Nodo,
        lists:flatten(io_lib:format("~s se unio al cluster", [Nodo]))),
      Nuevo = cambiar(State#{conectados := lists:usort([Nodo | Conectados])}),
      %% Que el servidor pregunte las versiones de los demas (ver server.erl).
      gen_server:cast(p15_cluster_de_2_3_nodos_server, sincronizar),
      {noreply, Nuevo};
    false ->
      %% Un nodo que no es miembro no suma al quorum ni se registra.
      {noreply, State}
  end;
handle_info({nodedown, Nodo}, #{miembros := Miembros, conectados := Conectados} = State) ->
  case lists:member(Nodo, Miembros) of
    true ->
      p15_cluster_de_2_3_nodos_eventos:registrar(nodo_caido, Nodo,
        lists:flatten(io_lib:format("~s dejo de responder", [Nodo]))),
      {noreply, cambiar(State#{conectados := lists:delete(Nodo, Conectados)})};
    false ->
      {noreply, State}
  end;
handle_info(reintentar, #{miembros := Miembros, conectados := Conectados} = State) ->
  %% net_adm:ping puede tardar varios segundos con un nodo inalcanzable; se hace
  %% en un proceso aparte para no bloquear al monitor.
  [spawn(fun() -> net_adm:ping(N) end) || N <- Miembros -- Conectados],
  erlang:send_after(?REINTENTO_MS, self(), reintentar),
  {noreply, State};
handle_info(_Info, State) ->
  {noreply, State}.

%% Aplica un cambio de conectados y avisa si cambio el lider.
cambiar(#{lider := LiderAntes} = State) ->
  #{lider := LiderDespues} = Nuevo = recalcular(State),
  case LiderDespues =:= LiderAntes of
    true -> ok;
    false ->
      p15_cluster_de_2_3_nodos_eventos:registrar(cambio_lider, node(), mensaje_lider(LiderDespues))
  end,
  Nuevo.

recalcular(#{miembros := Miembros, conectados := Conectados} = State) ->
  State#{lider := p15_cluster_de_2_3_nodos_membresia:lider(Conectados, Miembros)}.

mensaje_lider(sin_lider) ->
  "sin lider: no hay quorum (mayoria de nodos)";
mensaje_lider(Lider) ->
  lists:flatten(io_lib:format("~s es el lider: nodo de nombre menor entre los conectados", [Lider])).

foto(#{miembros := Miembros, conectados := Conectados, lider := Lider}) ->
  #{nodo => node(),
    miembros => Miembros,
    conectados => Conectados,
    quorum_necesario => p15_cluster_de_2_3_nodos_membresia:quorum_necesario(length(Miembros)),
    quorum => p15_cluster_de_2_3_nodos_membresia:hay_quorum(Conectados, Miembros),
    lider => Lider,
    rol => p15_cluster_de_2_3_nodos_membresia:rol(node(), Conectados, Miembros)}.
