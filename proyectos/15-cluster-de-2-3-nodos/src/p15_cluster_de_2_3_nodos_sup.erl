-module(p15_cluster_de_2_3_nodos_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

start_link() ->
  supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%% Arbol identico en cada nodo. Estrategia rest_for_one porque los hijos SI
%% dependen unos de otros en orden de arranque:
%%   1. eventos  : bitacora; nadie le avisa nada, todos le escriben.
%%   2. monitor  : necesita la bitacora viva para registrar caidas y reconexiones.
%%   3. server   : el estado replicado; lo decide el quorum que calcula el monitor.
%% Si cae eventos o monitor, se reinician tambien los que vienen despues (el server
%% vuelve con estado limpio y, en la etapa de replicacion, lo pide al lider). Si
%% solo cae el server, los de antes no se tocan.
init([]) ->
  Children = [
    #{id => p15_cluster_de_2_3_nodos_eventos,
      start => {p15_cluster_de_2_3_nodos_eventos, start_link, []},
      restart => permanent, shutdown => 5000, type => worker},
    #{id => p15_cluster_de_2_3_nodos_monitor,
      start => {p15_cluster_de_2_3_nodos_monitor, start_link, []},
      restart => permanent, shutdown => 5000, type => worker},
    #{id => p15_cluster_de_2_3_nodos_server,
      start => {p15_cluster_de_2_3_nodos_server, start_link, []},
      restart => permanent, shutdown => 5000, type => worker}
  ],
  {ok, {#{strategy => rest_for_one, intensity => 10, period => 60}, Children}}.
