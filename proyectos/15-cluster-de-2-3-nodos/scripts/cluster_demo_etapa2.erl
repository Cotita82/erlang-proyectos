%% Demo de la Etapa 2 con 3 nodos REALES en la misma maquina (n1, n2, n3) y un
%% nodo controlador (ctl) que los observa. Muestra el contador replicado, una
%% particion de red con escrituras concurrentes en ambos lados, la caida del lider
%% y el regreso de un nodo sin datos.
%% Uso: sh scripts/demo_etapa2.sh
-module(cluster_demo_etapa2).
-export([run/0, local_start/0, bloquear/1, desbloquear/1]).

-define(N1, 'n1@127.0.0.1').
-define(N2, 'n2@127.0.0.1').
-define(N3, 'n3@127.0.0.1').
-define(SRV, p15_cluster_de_2_3_nodos_server).
-define(MON, p15_cluster_de_2_3_nodos_monitor).
-define(SUP, p15_cluster_de_2_3_nodos_sup).
-define(E, p15_cluster_de_2_3_nodos_eventos).

%% Arranca el arbol de supervision en el nodo actual, con los 3 miembros.
local_start() ->
  application:set_env(p15_cluster_de_2_3_nodos, nodos, [?N1, ?N2, ?N3]),
  {ok, Pid} = ?SUP:start_link(),
  unlink(Pid),
  ok.

%% Simula una particion: cookie incorrecta hacia esos nodos y se les desconecta.
bloquear(Nodos) ->
  %% La cookie "mala" es distinta en cada nodo: si fuera la misma en los dos lados,
  %% la autenticacion coincidiria y la conexion se restablece sola.
  Mala = list_to_atom("cookie_mala_de_" ++ atom_to_list(node())),
  [begin erlang:set_cookie(N, Mala), erlang:disconnect_node(N) end || N <- Nodos],
  ok.

desbloquear(Nodos) ->
  [erlang:set_cookie(N, erlang:get_cookie()) || N <- Nodos],
  ok.

lanzar(Nodo) ->
  Ebin = filename:dirname(code:which(?MON)),
  Demo = filename:dirname(code:which(?MODULE)),
  Cmd = io_lib:format("erl -name ~s -noshell -detached -kernel prevent_overlapping_partitions false -pa ~s -pa ~s -eval 'cluster_demo_etapa2:local_start().'",
                      [Nodo, Ebin, Demo]),
  os:cmd(lists:flatten(Cmd)).

run() ->
  logger:set_primary_config(level, emergency),
  lanzar(?N1), lanzar(?N2), lanzar(?N3),
  timer:sleep(9000),
  paso("1) Los 3 nodos arriba"),
  ver([?N1, ?N2, ?N3]),

  paso("2) Tres incrementos pedidos al nodo n2 (seguidor): se reenvian al lider n1"),
  [io:format("  incrementar en n2 -> ~p~n", [rpc:call(?N2, ?SRV, incrementar, [])]) || _ <- [1,2,3]],
  timer:sleep(300),
  ver([?N1, ?N2, ?N3]),

  paso("3) PARTICION DE RED: n3 queda aislado de n1 y n2"),
  rpc:call(?N3, ?MODULE, bloquear, [[?N1, ?N2]]),
  rpc:call(?N1, ?MODULE, bloquear, [[?N3]]),
  rpc:call(?N2, ?MODULE, bloquear, [[?N3]]),
  timer:sleep(1500),
  ver([?N1, ?N2, ?N3]),

  paso("4) 5 escrituras a cada lado AL MISMO TIEMPO (lado de 2 nodos vs lado de 1)"),
  Pedidos = [?N1, ?N2, ?N1, ?N2, ?N1, ?N3, ?N3, ?N3, ?N3, ?N3],
  Tareas = [{N, rpc:async_call(N, ?SRV, incrementar, [])} || N <- Pedidos],
  Resultados = [{N, rpc:yield(T)} || {N, T} <- Tareas],
  Mayoria = [R || {N, R} <- Resultados, N =/= ?N3],
  Minoria = [R || {N, R} <- Resultados, N =:= ?N3],
  io:format("  lado de n1+n2: ~p aceptadas, ~p rechazadas~n",
            [length([ok || {ok, _} <- Mayoria]), length([x || {error, _} <- Mayoria])]),
  io:format("  lado de n3   : ~p aceptadas, ~p rechazadas (~p)~n",
            [length([ok || {ok, _} <- Minoria]), length([x || {error, _} <- Minoria]),
             lists:usort([M || {error, M} <- Minoria])]),
  ver([?N1, ?N2, ?N3]),

  paso("5) Se cura la particion: n3 vuelve y se pone al dia solo"),
  rpc:call(?N3, ?MODULE, desbloquear, [[?N1, ?N2]]),
  rpc:call(?N1, ?MODULE, desbloquear, [[?N3]]),
  rpc:call(?N2, ?MODULE, desbloquear, [[?N3]]),
  timer:sleep(9000),
  ver([?N1, ?N2, ?N3]),

  paso("6) Cae el lider n1: n2 asume y se sigue escribiendo (pedido a n3)"),
  rpc:call(?N1, erlang, halt, []),
  timer:sleep(1500),
  ver([?N2, ?N3]),
  io:format("  incrementar en n3 -> ~p~n", [rpc:call(?N3, ?SRV, incrementar, [])]),

  paso("7) n1 REGRESA SIN DATOS (version 0). Vuelve a ser lider por nombre, pero adopta la version mas alta"),
  lanzar(?N1),
  timer:sleep(9000),
  ver([?N1, ?N2, ?N3]),
  io:format("  incrementar en n1 -> ~p   (el contador sigue, no vuelve a 1)~n",
            [rpc:call(?N1, ?SRV, incrementar, [])]),
  timer:sleep(300),
  ver([?N1, ?N2, ?N3]),

  paso("8) Red de seguridad: se fuerza a n1 (lider) a quedar atrasado (version 0) y se le pide escribir"),
  rpc:call(?N1, sys, replace_state, [?SRV, fun(S) -> S#{valor := 0, version := 0} end]),
  ver([?N1]),
  io:format("  incrementar en n1 -> ~p   (los seguidores le avisan que esta atrasado, adopta y reintenta)~n",
            [rpc:call(?N1, ?SRV, incrementar, [])]),
  timer:sleep(300),
  ver([?N1, ?N2, ?N3]),
  io:format("  ultimo evento de n1: ~s~n", [maps:get(mensaje, hd(rpc:call(?N1, ?E, listar, [])))]),

  io:format("~nBitacora de eventos de n3 (del mas reciente al mas antiguo):~n"),
  [io:format("  ~-20s ~s~n", [maps:get(tipo, Ev), maps:get(mensaje, Ev)])
   || Ev <- rpc:call(?N3, ?E, listar, [])],
  [rpc:call(N, erlang, halt, []) || N <- [?N1, ?N2, ?N3]],
  ok.

paso(Titulo) ->
  io:format("~n=== ~s ===~n", [Titulo]).

ver(Nodos) ->
  [begin
     V = rpc:call(N, ?SRV, valor, []),
     E = rpc:call(N, ?MON, estado, []),
     io:format("  ~s  valor=~p version=~p | quorum=~p rol=~p~n",
               [N, maps:get(valor, V), maps:get(version, V),
                maps:get(quorum, E), maps:get(rol, E)])
   end || N <- Nodos],
  ok.
