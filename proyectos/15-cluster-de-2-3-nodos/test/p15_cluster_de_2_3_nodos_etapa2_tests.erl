%% Pruebas de la Etapa 2: contador replicado, versiones, escritura en dos fases,
%% rechazo sin quorum y puesta al dia. La replicacion entre nodos reales se
%% prueba con la demo (scripts/demo_etapa2.sh); aqui se prueba el protocolo
%% de cada nodo por separado.
-module(p15_cluster_de_2_3_nodos_etapa2_tests).
-include_lib("eunit/include/eunit.hrl").

-define(SRV, p15_cluster_de_2_3_nodos_server).
-define(MON, p15_cluster_de_2_3_nodos_monitor).
-define(E, p15_cluster_de_2_3_nodos_eventos).
-define(SUP, p15_cluster_de_2_3_nodos_sup).

%% -------------------------------------------------- cluster de un solo nodo

un_nodo_test_() ->
  {foreach,
    fun() -> iniciar([node()]) end,
    fun(_) -> detener_todo() end,
    [fun incrementa_y_sube_la_version/1,
     fun el_estado_sigue_siendo_un_mapa/1,
     fun conserva_un_pendiente_mayor/1]}.

incrementa_y_sube_la_version(_) ->
  fun() ->
    ?assertEqual({ok, #{valor => 1, version => 1}}, ?SRV:incrementar()),
    ?assertEqual({ok, #{valor => 2, version => 2}}, ?SRV:incrementar()),
    ?assertEqual({ok, #{valor => 3, version => 3}}, ?SRV:incrementar()),
    ?assertEqual(#{valor => 3, version => 3}, ?SRV:valor())
  end.

el_estado_sigue_siendo_un_mapa(_) ->
  fun() ->
    ?assertEqual(pong, ?SRV:ping()),
    ?assert(is_map(?SRV:state())),
    ?assertEqual(0, maps:get(valor, ?SRV:state())),
    ?assertEqual(0, maps:get(version, ?SRV:state()))
  end.

%% Una escritura que la mayoria alcanzo a guardar (pendiente) no se pierde si el
%% lider cae antes de confirmar: el siguiente lider la conserva.
conserva_un_pendiente_mayor(_) ->
  fun() ->
    ?assertEqual(ack, gen_server:call(?SRV, {preparar, 3, 30})),
    ?assertEqual({ok, #{valor => 31, version => 4}}, ?SRV:incrementar())
  end.

%% -------------------------------------------------- protocolo del seguidor

seguidor_test_() ->
  {foreach,
    fun() -> iniciar([node()]) end,
    fun(_) -> detener_todo() end,
    [fun preparar_no_cambia_el_valor_hasta_confirmar/1,
     fun descartar_borra_el_pendiente/1,
     fun rechaza_propuestas_de_un_lider_atrasado/1,
     fun ignora_confirmaciones_de_otra_version/1]}.

preparar_no_cambia_el_valor_hasta_confirmar(_) ->
  fun() ->
    ?assertEqual(ack, gen_server:call(?SRV, {preparar, 1, 10})),
    ?assertEqual(#{valor => 0, version => 0}, ?SRV:valor()),
    ?assertEqual({1, 10}, gen_server:call(?SRV, estado_replica)),
    gen_server:cast(?SRV, {confirmar, 1}),
    ?assertEqual(#{valor => 10, version => 1}, ?SRV:valor())
  end.

descartar_borra_el_pendiente(_) ->
  fun() ->
    ?assertEqual(ack, gen_server:call(?SRV, {preparar, 1, 10})),
    gen_server:cast(?SRV, {descartar, 1}),
    ?assertEqual({0, 0}, gen_server:call(?SRV, estado_replica)),
    ?assertEqual(#{valor => 0, version => 0}, ?SRV:valor())
  end.

rechaza_propuestas_de_un_lider_atrasado(_) ->
  fun() ->
    ?assertEqual(ack, gen_server:call(?SRV, {preparar, 2, 20})),
    gen_server:cast(?SRV, {confirmar, 2}),
    %% Un lider que vuelve sin datos propone la version 1: se le contesta con lo mas reciente.
    ?assertEqual({nack, {2, 20}}, gen_server:call(?SRV, {preparar, 1, 10})),
    ?assertEqual({nack, {2, 20}}, gen_server:call(?SRV, {preparar, 2, 99})),
    ?assertEqual(#{valor => 20, version => 2}, ?SRV:valor())
  end.

ignora_confirmaciones_de_otra_version(_) ->
  fun() ->
    ?assertEqual(ack, gen_server:call(?SRV, {preparar, 1, 10})),
    gen_server:cast(?SRV, {confirmar, 5}),
    ?assertEqual(#{valor => 0, version => 0}, ?SRV:valor())
  end.

%% -------------------------------------------------- puesta al dia

puesta_al_dia_test_() ->
  {foreach,
    fun() -> iniciar([node()]) end,
    fun(_) -> detener_todo() end,
    [fun adopta_la_version_mas_alta/1,
     fun ignora_versiones_menores/1]}.

adopta_la_version_mas_alta(_) ->
  fun() ->
    whereis(?SRV) ! {estados_pares, [{'zz1@h', 5, 50}, {'zz2@h', 3, 30}]},
    ?assertEqual(#{valor => 50, version => 5}, ?SRV:valor()),
    Tipos = [maps:get(tipo, Ev) || Ev <- ?E:listar()],
    ?assert(lists:member(resincronizacion, Tipos))
  end.

ignora_versiones_menores(_) ->
  fun() ->
    whereis(?SRV) ! {estados_pares, [{'zz1@h', 5, 50}]},
    whereis(?SRV) ! {estados_pares, [{'zz1@h', 4, 40}]},
    ?assertEqual(#{valor => 50, version => 5}, ?SRV:valor())
  end.

%% -------------------------------------------------- sin quorum

sin_quorum_test_() ->
  {foreach,
    fun() -> iniciar([node(), 'zz1@h', 'zz2@h']) end,
    fun(_) -> detener_todo() end,
    [fun rechaza_escrituras_sin_quorum/1,
     fun el_valor_no_cambia_si_se_rechaza/1]}.

rechaza_escrituras_sin_quorum(_) ->
  fun() ->
    ?assertEqual({error, sin_quorum}, ?SRV:incrementar()),
    [Evento | _] = ?E:listar(),
    ?assertEqual(escritura_rechazada, maps:get(tipo, Evento))
  end.

el_valor_no_cambia_si_se_rechaza(_) ->
  fun() ->
    [?SRV:incrementar() || _ <- lists:seq(1, 5)],
    ?assertEqual(#{valor => 0, version => 0}, ?SRV:valor())
  end.

%% ------------------------------------------------------------------ ayudas

iniciar(Miembros) ->
  detener_todo(),
  {ok, E} = ?E:start_link(), unlink(E),
  application:set_env(p15_cluster_de_2_3_nodos, nodos, Miembros),
  {ok, M} = ?MON:start_link(), unlink(M),
  {ok, S} = ?SRV:start_link(), unlink(S),
  ok.

detener_todo() ->
  [detener(N) || N <- [?SUP, ?SRV, ?MON, ?E]],
  application:unset_env(p15_cluster_de_2_3_nodos, nodos),
  ok.

detener(Nombre) ->
  case whereis(Nombre) of
    undefined -> ok;
    Pid ->
      unlink(Pid),
      exit(Pid, kill),
      esperar(fun() -> whereis(Nombre) =:= undefined end, 300)
  end.

esperar(_Condicion, 0) -> error(tiempo_de_espera_agotado);
esperar(Condicion, N) ->
  case Condicion() of
    true -> ok;
    false -> timer:sleep(10), esperar(Condicion, N - 1)
  end.
