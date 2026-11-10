%% Servicio replicado: un CONTADOR compartido entre los nodos del cluster.
%%
%% Reglas de diseno (frente al teorema CAP):
%%  - Consistencia sobre disponibilidad: solo escribe quien ve la MAYORIA (quorum).
%%    El lado minoritario de una particion RECHAZA las escrituras.
%%  - Solo el lider escribe. Cualquier nodo puede recibir la peticion y la reenvia.
%%  - Cada escritura sube un numero de VERSION. Lo que manda es la version, no el
%%    reloj, asi un nodo con la hora adelantada no puede ganarle a otro.
%%  - Escritura en dos fases (preparar/confirmar): el valor solo cambia cuando la
%%    mayoria ya lo guardo como "pendiente". Si no hay mayoria, se descarta y no
%%    queda ningun nodo con un valor que otros no tengan.
%%  - Nodo que regresa atrasado: copia el estado con la version MAS ALTA entre los
%%    nodos que ve (no el del lider: el lider por nombre podria ser el que volvio
%%    sin datos). Cualquier escritura confirmada esta en al menos una mayoria, y toda
%%    mayoria se cruza con la que ve el nodo, asi que esa version mas alta existe.
-module(p15_cluster_de_2_3_nodos_server).
-behaviour(gen_server).

-export([start_link/0, ping/0, state/0]).
-export([incrementar/0, valor/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-define(MON, p15_cluster_de_2_3_nodos_monitor).
-define(EV, p15_cluster_de_2_3_nodos_eventos).
-define(TIMEOUT_REPLICA, 2000).
-define(TIMEOUT_ESCRITURA, 10000).

start_link() ->
  gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

ping() ->
  gen_server:call(?MODULE, ping).

state() ->
  gen_server:call(?MODULE, state).

%% incrementar(): se puede llamar en CUALQUIER nodo.
%%   {ok, #{valor, version}}  la mayoria lo confirmo
%%   {error, sin_quorum}      este nodo no ve a la mayoria: se rechaza
%%   {error, lider_no_responde} | {error, sin_confirmacion_de_mayoria} | ...
incrementar() ->
  case ?MON:estado() of
    #{quorum := false, conectados := Conectados, miembros := Miembros,
      quorum_necesario := Necesario} ->
      ?EV:registrar(escritura_rechazada, node(),
        fmt("sin quorum: este nodo ve ~p de ~p y se requieren ~p",
            [length(Conectados), length(Miembros), Necesario])),
      {error, sin_quorum};
    #{lider := Lider} ->
      try gen_server:call({?MODULE, Lider}, escribir, ?TIMEOUT_ESCRITURA)
      catch exit:_ -> {error, lider_no_responde}
      end
  end.

%% Lectura LOCAL. En el lado minoritario de una particion puede estar atrasada.
valor() ->
  gen_server:call(?MODULE, valor).

%% Estado como mapa para poder agregar campos del dominio sin romper los callbacks.
init([]) ->
  logger:info("~s iniciado", [?MODULE], #{proyecto => p15_cluster_de_2_3_nodos}),
  %% Si al arrancar ya hay otros nodos, se pone al dia con ellos.
  gen_server:cast(self(), sincronizar),
  {ok, #{iniciado_en => erlang:system_time(second),
         valor => 0,
         version => 0,
         pendiente => undefined}}.

handle_call(ping, _From, State) ->
  {reply, pong, State};
handle_call(state, _From, State) ->
  {reply, State, State};
handle_call(valor, _From, #{valor := Valor, version := Version} = State) ->
  {reply, #{valor => Valor, version => Version}, State};
%% Lo que un par pregunta para ponerse al dia: la version mas alta que conozco.
handle_call(estado_replica, _From, State) ->
  {reply, mejor_estado(State), State};
%% Fase 1 (seguidor): guardar como pendiente si la version es nueva; si el que
%% propone esta atrasado, se le responde con el estado mas reciente.
handle_call({preparar, Version, Valor}, _From, #{version := Actual} = State)
  when Version > Actual ->
  {reply, ack, State#{pendiente := {Version, Valor}}};
handle_call({preparar, _Version, _Valor}, _From, State) ->
  {reply, {nack, mejor_estado(State)}, State};
%% Escritura (lider).
handle_call(escribir, _From, State) ->
  escribir(promover_pendiente(State), 2).

%% Fase 2 (seguidor): la mayoria ya guardo la version, se aplica.
handle_cast({confirmar, Version}, #{pendiente := {Version, Valor}, version := Actual} = State) ->
  case Version - Actual > 1 of
    true ->
      ?EV:registrar(resincronizacion, node(),
        fmt("se puso al dia: de v~p a v~p", [Actual, Version]));
    false -> ok
  end,
  {noreply, State#{valor := Valor, version := Version, pendiente := undefined}};
handle_cast({confirmar, _Otra}, State) ->
  {noreply, State};
%% No hubo mayoria: se descarta lo pendiente.
handle_cast({descartar, Version}, #{pendiente := {Version, _}} = State) ->
  {noreply, State#{pendiente := undefined}};
handle_cast({descartar, _Otra}, State) ->
  {noreply, State};
%% Preguntar a los demas su version, en un proceso aparte para no bloquear al
%% servidor (dos nodos preguntandose a la vez se quedarian esperando).
handle_cast(sincronizar, State) ->
  Servidor = self(),
  spawn(fun() -> Servidor ! {estados_pares, consultar_pares()} end),
  {noreply, State};
handle_cast(_Msg, State) ->
  {noreply, State}.

handle_info({estados_pares, []}, State) ->
  {noreply, State};
handle_info({estados_pares, Pares}, #{version := Actual, pendiente := Pendiente} = State) ->
  {Mejor, ValorMejor, Origen} = lists:max([{V, Val, N} || {N, V, Val} <- Pares]),
  case Mejor > Actual of
    true ->
      ?EV:registrar(resincronizacion, node(),
        fmt("se puso al dia: de v~p a v~p (copiado de ~s)", [Actual, Mejor, Origen])),
      Pendiente1 = case Pendiente of
                     {PV, _} when PV =< Mejor -> undefined;
                     Otro -> Otro
                   end,
      {noreply, State#{valor := ValorMejor, version := Mejor, pendiente := Pendiente1}};
    false ->
      {noreply, State}
  end;
handle_info(_Info, State) ->
  {noreply, State}.

%% ---------------------------------------------------------------- lider

escribir(State, Intentos) ->
  case ?MON:estado() of
    #{quorum := true, lider := Lider, conectados := Conectados,
      quorum_necesario := Necesario} when Lider =:= node() ->
      replicar(State, Conectados -- [node()], Necesario, Intentos);
    #{quorum := true, lider := Lider} ->
      {reply, {error, {no_soy_lider, Lider}}, State};
    _ ->
      ?EV:registrar(escritura_rechazada, node(), "sin quorum al intentar escribir"),
      {reply, {error, sin_quorum}, State}
  end.

replicar(#{valor := Valor0, version := Version0} = State, Seguidores, Necesario, Intentos) ->
  Version = Version0 + 1,
  Valor = Valor0 + 1,
  Respuestas = erpc:multicall(Seguidores, gen_server, call,
                              [?MODULE, {preparar, Version, Valor}, ?TIMEOUT_REPLICA],
                              ?TIMEOUT_REPLICA + 1000),
  Pares = lists:zip(Seguidores, Respuestas),
  Acks = [N || {N, {ok, ack}} <- Pares],
  Nacks = [{V, Val, N} || {N, {ok, {nack, {V, Val}}}} <- Pares],
  decidir(Nacks, Acks, State, Version, Valor, Necesario, Intentos).

%% Un seguidor tiene una version igual o mayor: ESTE lider estaba atrasado
%% (por ejemplo, acaba de volver sin datos). Adopta lo mas reciente y reintenta.
decidir([_ | _] = Nacks, Acks, #{version := Antes} = State, Version, _Valor, _Necesario, Intentos) ->
  descartar(Acks, Version),
  {Mejor, ValorMejor, Origen} = lists:max(Nacks),
  ?EV:registrar(resincronizacion, node(),
    fmt("el lider estaba atrasado: de v~p a v~p (copiado de ~s)", [Antes, Mejor, Origen])),
  Nuevo = State#{valor := ValorMejor, version := Mejor, pendiente := undefined},
  case Intentos > 0 of
    true -> escribir(Nuevo, Intentos - 1);
    false -> {reply, {error, estado_atrasado}, Nuevo}
  end;
%% Sin objeciones: se confirma si la mayoria (contando al lider) lo guardo.
decidir([], Acks, State, Version, Valor, Necesario, _Intentos) ->
  case length(Acks) + 1 >= Necesario of
    true ->
      [gen_server:cast({?MODULE, N}, {confirmar, Version}) || N <- Acks],
      {reply, {ok, #{valor => Valor, version => Version}},
       State#{valor := Valor, version := Version}};
    false ->
      descartar(Acks, Version),
      ?EV:registrar(escritura_rechazada, node(),
        fmt("solo ~p nodos guardaron la version ~p y se requieren ~p",
            [length(Acks) + 1, Version, Necesario])),
      {reply, {error, sin_confirmacion_de_mayoria}, State}
  end.

descartar(Nodos, Version) ->
  [gen_server:cast({?MODULE, N}, {descartar, Version}) || N <- Nodos],
  ok.

%% ------------------------------------------------------------- utilidades

%% Un pendiente mayor que lo confirmado puede ser una escritura que la mayoria
%% alcanzo a guardar antes de que el lider cayera: se conserva, no se pierde.
promover_pendiente(#{version := Version, pendiente := {PVersion, PValor}} = State)
  when PVersion > Version ->
  State#{valor := PValor, version := PVersion, pendiente := undefined};
promover_pendiente(State) ->
  State.

mejor_estado(#{version := Version, pendiente := {PVersion, PValor}})
  when PVersion > Version ->
  {PVersion, PValor};
mejor_estado(#{version := Version, valor := Valor}) ->
  {Version, Valor}.

%% Pregunta a los nodos conectados su mejor estado.
consultar_pares() ->
  try
    #{conectados := Conectados} = ?MON:estado(),
    Pares = Conectados -- [node()],
    Respuestas = erpc:multicall(Pares, gen_server, call,
                                [?MODULE, estado_replica, ?TIMEOUT_REPLICA],
                                ?TIMEOUT_REPLICA + 1000),
    [{N, V, Val} || {N, {ok, {V, Val}}} <- lists:zip(Pares, Respuestas)]
  catch _:_ -> []
  end.

fmt(Formato, Args) ->
  lists:flatten(io_lib:format(Formato, Args)).
