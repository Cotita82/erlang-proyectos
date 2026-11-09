%% Pruebas de la Etapa 1: membresia (quorum y lider), bitacora de eventos,
%% monitor de nodos y reinicio del arbol de supervision (rest_for_one).
-module(p15_cluster_de_2_3_nodos_etapa1_tests).
-include_lib("eunit/include/eunit.hrl").

-define(M, p15_cluster_de_2_3_nodos_membresia).
-define(E, p15_cluster_de_2_3_nodos_eventos).
-define(MON, p15_cluster_de_2_3_nodos_monitor).
-define(SUP, p15_cluster_de_2_3_nodos_sup).
-define(SRV, p15_cluster_de_2_3_nodos_server).

%% ---------------------------------------------------------------- membresia

quorum_necesario_test_() ->
  [?_assertEqual(1, ?M:quorum_necesario(1)),
   ?_assertEqual(2, ?M:quorum_necesario(2)),   % con 2 nodos no se tolera ninguna caida
   ?_assertEqual(2, ?M:quorum_necesario(3)),   % con 3 se tolera la caida de 1
   ?_assertEqual(3, ?M:quorum_necesario(5))].

quorum_con_tres_miembros_test_() ->
  Miembros = [n1, n2, n3],
  [?_assert(?M:hay_quorum([n1, n2, n3], Miembros)),          % 3 de 3
   ?_assert(?M:hay_quorum([n1, n2], Miembros)),              % 2 de 3
   ?_assert(?M:hay_quorum([n2, n3], Miembros)),
   ?_assertNot(?M:hay_quorum([n3], Miembros)),               % 1 de 3
   ?_assertNot(?M:hay_quorum([], Miembros))].

quorum_ignora_nodos_ajenos_test_() ->
  %% Un nodo que no es miembro no cuenta, ni aunque se conecte.
  [?_assertNot(?M:hay_quorum([n1, intruso1, intruso2], [n1, n2, n3])),
   ?_assert(?M:hay_quorum([n1, n2, intruso1], [n1, n2, n3])),
   %% Duplicados no inflan el conteo.
   ?_assertNot(?M:hay_quorum([n1, n1, n1], [n1, n2, n3]))].

nodo_solo_test_() ->
  [?_assert(?M:hay_quorum([n1], [n1])),
   ?_assertEqual(n1, ?M:lider([n1], [n1]))].

lider_es_el_nombre_menor_con_quorum_test_() ->
  Miembros = [n1, n2, n3],
  [?_assertEqual(n1, ?M:lider([n1, n2, n3], Miembros)),
   ?_assertEqual(n2, ?M:lider([n2, n3], Miembros)),   % cae n1: asume n2
   ?_assertEqual(n1, ?M:lider([n3, n1], Miembros)),   % el orden de la lista no importa
   ?_assertEqual(sin_lider, ?M:lider([n3], Miembros))].

rol_test_() ->
  Miembros = [n1, n2, n3],
  [?_assertEqual(lider, ?M:rol(n1, [n1, n2, n3], Miembros)),
   ?_assertEqual(seguidor, ?M:rol(n2, [n1, n2, n3], Miembros)),
   ?_assertEqual(sin_quorum, ?M:rol(n3, [n3], Miembros)),
   %% Dos lados de una particion: el lado de 2 manda, el de 1 no.
   ?_assertEqual(lider, ?M:rol(n1, [n1, n2], Miembros)),
   ?_assertEqual(sin_quorum, ?M:rol(n3, [n3], Miembros))].

%% ------------------------------------------------------------------ eventos

eventos_test_() ->
  {foreach,
    fun iniciar_eventos/0,
    fun(_) -> detener(?E) end,
    [fun registra_y_lista_del_mas_reciente_al_mas_antiguo/1,
     fun rechaza_tipos_invalidos/1,
     fun es_circular_con_maximo_200/1,
     fun limpiar_vacia_la_bitacora/1]}.

registra_y_lista_del_mas_reciente_al_mas_antiguo(_) ->
  fun() ->
    ?E:registrar(nodo_caido, n3, "n3 dejo de responder"),
    ?E:registrar(nodo_reconectado, n3, "n3 se unio"),
    [Ultimo, Primero] = ?E:listar(),
    ?assertEqual(nodo_reconectado, maps:get(tipo, Ultimo)),
    ?assertEqual(nodo_caido, maps:get(tipo, Primero)),
    ?assertEqual(n3, maps:get(nodo, Primero)),
    ?assertEqual("n3 dejo de responder", maps:get(mensaje, Primero)),
    ?assert(is_integer(maps:get(timestamp, Primero)))
  end.

rechaza_tipos_invalidos(_) ->
  fun() ->
    ?assertError({tipo_de_evento_invalido, raft_election},
                 ?E:registrar(raft_election, n1, "no existe en este diseno")),
    ?assertEqual([], ?E:listar())
  end.

es_circular_con_maximo_200(_) ->
  fun() ->
    [?E:registrar(cambio_lider, n1, integer_to_list(I)) || I <- lists:seq(1, 250)],
    Eventos = ?E:listar(),
    ?assertEqual(200, length(Eventos)),
    %% Se conservan los 200 mas recientes: del 250 al 51.
    ?assertEqual("250", maps:get(mensaje, hd(Eventos))),
    ?assertEqual("51", maps:get(mensaje, lists:last(Eventos)))
  end.

limpiar_vacia_la_bitacora(_) ->
  fun() ->
    ?E:registrar(escritura_rechazada, n3, "sin quorum"),
    ?assertEqual(ok, ?E:limpiar()),
    ?assertEqual([], ?E:listar())
  end.

%% ------------------------------------------------------------------ monitor
%% Los nodos se simulan enviando al monitor los mismos mensajes que manda
%% net_kernel (nodeup / nodedown). La logica es la misma que con red real.
%% 'zz1@h' y 'zz2@h' son mayores que nonode@nohost, asi que este nodo es el lider
%% cuando hay quorum.

monitor_test_() ->
  {foreach,
    fun iniciar_monitor/0,
    fun(_) ->
      detener(?MON),
      detener(?E),
      application:unset_env(p15_cluster_de_2_3_nodos, nodos)
    end,
    [fun arranca_sin_quorum_si_esta_solo/1,
     fun gana_quorum_y_liderazgo_al_entrar_un_nodo/1,
     fun pierde_quorum_al_caer_un_nodo/1,
     fun ignora_nodos_que_no_son_miembros/1,
     fun registra_eventos_de_membresia/1]}.

arranca_sin_quorum_si_esta_solo(_) ->
  fun() ->
    Estado = ?MON:estado(),
    ?assertEqual(3, length(maps:get(miembros, Estado))),
    ?assertEqual(2, maps:get(quorum_necesario, Estado)),
    ?assertEqual([node()], maps:get(conectados, Estado)),
    ?assertEqual(false, maps:get(quorum, Estado)),
    ?assertEqual(sin_lider, maps:get(lider, Estado)),
    ?assertEqual(sin_quorum, maps:get(rol, Estado))
  end.

gana_quorum_y_liderazgo_al_entrar_un_nodo(_) ->
  fun() ->
    whereis(?MON) ! {nodeup, 'zz1@h'},
    Estado = ?MON:estado(),
    ?assertEqual(true, maps:get(quorum, Estado)),
    ?assertEqual(node(), maps:get(lider, Estado)),
    ?assertEqual(lider, maps:get(rol, Estado))
  end.

pierde_quorum_al_caer_un_nodo(_) ->
  fun() ->
    whereis(?MON) ! {nodeup, 'zz1@h'},
    whereis(?MON) ! {nodedown, 'zz1@h'},
    Estado = ?MON:estado(),
    ?assertEqual(false, maps:get(quorum, Estado)),
    ?assertEqual(sin_lider, maps:get(lider, Estado)),
    ?assertEqual([node()], maps:get(conectados, Estado))
  end.

ignora_nodos_que_no_son_miembros(_) ->
  fun() ->
    whereis(?MON) ! {nodeup, 'intruso@h'},
    Estado = ?MON:estado(),
    ?assertEqual([node()], maps:get(conectados, Estado)),
    ?assertEqual(false, maps:get(quorum, Estado)),
    ?assertEqual([], ?E:listar())
  end.

registra_eventos_de_membresia(_) ->
  fun() ->
    whereis(?MON) ! {nodeup, 'zz1@h'},
    whereis(?MON) ! {nodedown, 'zz1@h'},
    _ = ?MON:estado(),
    Tipos = [maps:get(tipo, Ev) || Ev <- ?E:listar()],
    %% Del mas reciente al mas antiguo: cae el nodo y se pierde el lider,
    %% luego se gana el lider y entra el nodo.
    ?assertEqual([cambio_lider, nodo_caido, cambio_lider, nodo_reconectado], Tipos)
  end.

%% -------------------------------------------------------------- supervision

supervision_test_() ->
  {foreach,
    fun() ->
      limpiar_todo(),
      {ok, Sup} = ?SUP:start_link(),
      Sup
    end,
    fun(Sup) ->
      unlink(Sup),
      exit(Sup, shutdown),
      esperar(fun() -> whereis(?SUP) =:= undefined end)
    end,
    [fun(_) -> fun si_cae_eventos_se_reinician_monitor_y_server/0 end,
     fun(_) -> fun si_cae_el_monitor_se_reinicia_el_server_pero_no_eventos/0 end,
     fun(_) -> fun si_cae_el_server_no_se_toca_a_los_demas/0 end]}.

si_cae_eventos_se_reinician_monitor_y_server() ->
  Antes = pids(),
  exit(whereis(?E), kill),
  esperar(fun() -> todos_vivos() andalso pids() =/= Antes end),
  Despues = pids(),
  ?assertNotEqual(maps:get(eventos, Antes), maps:get(eventos, Despues)),
  ?assertNotEqual(maps:get(monitor, Antes), maps:get(monitor, Despues)),
  ?assertNotEqual(maps:get(server, Antes), maps:get(server, Despues)).

si_cae_el_monitor_se_reinicia_el_server_pero_no_eventos() ->
  Antes = pids(),
  exit(whereis(?MON), kill),
  esperar(fun() -> todos_vivos() andalso pids() =/= Antes end),
  Despues = pids(),
  ?assertEqual(maps:get(eventos, Antes), maps:get(eventos, Despues)),
  ?assertNotEqual(maps:get(monitor, Antes), maps:get(monitor, Despues)),
  ?assertNotEqual(maps:get(server, Antes), maps:get(server, Despues)).

si_cae_el_server_no_se_toca_a_los_demas() ->
  Antes = pids(),
  exit(whereis(?SRV), kill),
  esperar(fun() -> todos_vivos() andalso pids() =/= Antes end),
  Despues = pids(),
  ?assertEqual(maps:get(eventos, Antes), maps:get(eventos, Despues)),
  ?assertEqual(maps:get(monitor, Antes), maps:get(monitor, Despues)),
  ?assertNotEqual(maps:get(server, Antes), maps:get(server, Despues)).

%% ----------------------------------------------------------------- ayudas

iniciar_eventos() ->
  limpiar_todo(),
  {ok, Pid} = ?E:start_link(),
  unlink(Pid),
  Pid.

iniciar_monitor() ->
  limpiar_todo(),
  {ok, E} = ?E:start_link(),
  unlink(E),
  application:set_env(p15_cluster_de_2_3_nodos, nodos, [node(), 'zz1@h', 'zz2@h']),
  {ok, M} = ?MON:start_link(),
  unlink(M),
  ok.

%% Cada prueba empieza sin procesos viejos de pruebas anteriores
%% (el test del esqueleto apaga su arbol de forma asincrona).
limpiar_todo() ->
  [detener(N) || N <- [?SUP, ?SRV, ?MON, ?E]],
  ok.

detener(Nombre) ->
  case whereis(Nombre) of
    undefined -> ok;
    Pid ->
      unlink(Pid),
      exit(Pid, kill),
      esperar(fun() -> whereis(Nombre) =:= undefined end)
  end.

pids() ->
  #{eventos => whereis(?E), monitor => whereis(?MON), server => whereis(?SRV)}.

todos_vivos() ->
  lists:all(fun(P) -> is_pid(P) end, maps:values(pids())).

%% Espera hasta 3 s a que se cumpla una condicion.
esperar(Condicion) ->
  esperar(Condicion, 300).

esperar(_Condicion, 0) ->
  error(tiempo_de_espera_agotado);
esperar(Condicion, N) ->
  case Condicion() of
    true -> ok;
    false -> timer:sleep(10), esperar(Condicion, N - 1)
  end.
