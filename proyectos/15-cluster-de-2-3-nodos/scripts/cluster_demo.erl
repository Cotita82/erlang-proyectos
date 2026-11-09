%% Demo de la Etapa 1 con 3 nodos REALES en la misma maquina.
%% Mata nodos, los regresa y muestra quorum, lider y bitacora de eventos.
%% Uso: sh scripts/demo_etapa1.sh
-module(cluster_demo).
-export([run/0, local_start/0]).

-define(N1, 'n1@127.0.0.1').
-define(N2, 'n2@127.0.0.1').
-define(N3, 'n3@127.0.0.1').
-define(SUP, p15_cluster_de_2_3_nodos_sup).
-define(MON, p15_cluster_de_2_3_nodos_monitor).
-define(E, p15_cluster_de_2_3_nodos_eventos).

%% Arranca el arbol de supervision en el nodo actual, con los 3 miembros.
local_start() ->
  application:set_env(p15_cluster_de_2_3_nodos, nodos, [?N1, ?N2, ?N3]),
  {ok, Pid} = ?SUP:start_link(),
  unlink(Pid),
  ok.

%% Lanza un nodo nuevo en segundo plano (como si se encendiera otra maquina).
lanzar(Nodo) ->
  Ebin = filename:dirname(code:which(?MON)),
  Demo = filename:dirname(code:which(?MODULE)),
  Cmd = io_lib:format("erl -name ~s -noshell -detached -pa ~s -pa ~s -eval 'cluster_demo:local_start().'",
                      [Nodo, Ebin, Demo]),
  os:cmd(lists:flatten(Cmd)).

run() ->
  net_kernel:start([?N1, longnames]),
  local_start(),
  lanzar(?N2), lanzar(?N3),
  %% Los reintentos del monitor (cada 5 s) los conectan solos.
  timer:sleep(7000),
  ver("1) Los 3 nodos arriba (se unieron solos, sin intervencion)", [?N1, ?N2, ?N3]),
  io:format("~n>>> Se mata n3~n"),
  rpc:call(?N3, erlang, halt, []),
  timer:sleep(1500),
  ver("2) Cae n3: quedan 2 de 3, aun hay quorum", [?N1, ?N2]),
  io:format("~n>>> Se mata n2: n1 queda solo~n"),
  rpc:call(?N2, erlang, halt, []),
  timer:sleep(1500),
  ver("3) Cae n2: n1 solo, SIN quorum", [?N1]),
  io:format("~n>>> Regresa n2 (arranca de nuevo, sin avisarle a nadie)~n"),
  lanzar(?N2),
  timer:sleep(7000),
  ver("4) n2 volvio solo: de nuevo hay quorum y lider", [?N1, ?N2]),
  io:format("~nEventos en n1 (del mas reciente al mas antiguo):~n"),
  [io:format("  ~-20s ~s~n", [maps:get(tipo, Ev), maps:get(mensaje, Ev)]) || Ev <- ?E:listar()],
  rpc:call(?N2, erlang, halt, []),
  ok.

ver(Titulo, Nodos) ->
  io:format("~n=== ~s ===~n", [Titulo]),
  [begin
     E = rpc:call(N, ?MON, estado, []),
     io:format("  ~s: conectados=~p quorum=~p lider=~p rol=~p~n",
               [N, length(maps:get(conectados, E)), maps:get(quorum, E),
                maps:get(lider, E), maps:get(rol, E)])
   end || N <- Nodos],
  ok.
