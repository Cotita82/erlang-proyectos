%% Bitacora circular de eventos del cluster (maximo 200).
%% Alimenta la pantalla "Historial y alertas" de la interfaz.
%% Es el primer hijo del supervisor: si cae, se reinicia todo lo que depende de el.
-module(p15_cluster_de_2_3_nodos_eventos).
-behaviour(gen_server).

-export([start_link/0, registrar/3, listar/0, limpiar/0, tipos/0, maximo/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-define(MAXIMO, 200).

%% Los 5 tipos de evento que muestra la interfaz.
tipos() ->
  [nodo_caido, nodo_reconectado, cambio_lider, escritura_rechazada, resincronizacion].

maximo() -> ?MAXIMO.

start_link() ->
  gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% registrar(Tipo, Nodo, Mensaje): asincrono, para que registrar un evento
%% nunca bloquee a quien lo reporta (por ejemplo el monitor de nodos).
registrar(Tipo, Nodo, Mensaje) ->
  case lists:member(Tipo, tipos()) of
    true -> gen_server:cast(?MODULE, {registrar, Tipo, Nodo, Mensaje});
    false -> erlang:error({tipo_de_evento_invalido, Tipo})
  end.

%% Eventos del mas reciente al mas antiguo.
listar() ->
  gen_server:call(?MODULE, listar).

limpiar() ->
  gen_server:call(?MODULE, limpiar).

init([]) ->
  {ok, #{eventos => []}}.

handle_call(listar, _From, #{eventos := Eventos} = State) ->
  {reply, Eventos, State};
handle_call(limpiar, _From, State) ->
  {reply, ok, State#{eventos := []}}.

handle_cast({registrar, Tipo, Nodo, Mensaje}, #{eventos := Eventos} = State) ->
  Evento = #{tipo => Tipo,
             nodo => Nodo,
             mensaje => Mensaje,
             timestamp => erlang:system_time(millisecond)},
  {noreply, State#{eventos := lists:sublist([Evento | Eventos], ?MAXIMO)}};
handle_cast(_Msg, State) ->
  {noreply, State}.

handle_info(_Info, State) ->
  {noreply, State}.
