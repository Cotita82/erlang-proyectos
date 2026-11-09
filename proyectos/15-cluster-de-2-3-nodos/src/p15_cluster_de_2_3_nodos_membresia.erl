%% Logica PURA de membresia: quorum y lider.
%% No usa procesos ni red, por eso es facil de probar con eunit.
%%
%% Regla de diseno (frente al teorema CAP):
%%  - Se prefiere CONSISTENCIA sobre disponibilidad.
%%  - Solo la mayoria (quorum) puede aceptar escrituras.
%%  - El lider NO se elige por votacion: es el nodo de nombre menor entre los
%%    conectados, y solo existe si hay quorum. Todos los nodos que ven el mismo
%%    conjunto de conectados calculan el mismo lider, sin intercambiar mensajes.
-module(p15_cluster_de_2_3_nodos_membresia).

-export([quorum_necesario/1, hay_quorum/2, lider/2, rol/3]).

%% Mayoria estricta: con 3 miembros se necesitan 2, con 2 miembros se necesitan 2
%% (por eso con 2 nodos no se tolera ninguna caida), con 1 miembro se necesita 1.
-spec quorum_necesario(pos_integer()) -> pos_integer().
quorum_necesario(N) when is_integer(N), N > 0 ->
  N div 2 + 1.

%% Solo cuentan los conectados que realmente pertenecen al cluster
%% (un nodo ajeno que se conecte no suma al quorum).
-spec hay_quorum([node()], [node()]) -> boolean().
hay_quorum(Conectados, Miembros) ->
  length(validos(Conectados, Miembros)) >= quorum_necesario(length(Miembros)).

%% Lider = nodo de nombre menor entre los conectados validos, solo con quorum.
-spec lider([node()], [node()]) -> node() | sin_lider.
lider(Conectados, Miembros) ->
  case hay_quorum(Conectados, Miembros) of
    true -> lists:min(validos(Conectados, Miembros));
    false -> sin_lider
  end.

%% Rol de un nodo desde su propio punto de vista.
-spec rol(node(), [node()], [node()]) -> lider | seguidor | sin_quorum.
rol(Nodo, Conectados, Miembros) ->
  case lider(Conectados, Miembros) of
    sin_lider -> sin_quorum;
    Nodo -> lider;
    _Otro -> seguidor
  end.

validos(Conectados, Miembros) ->
  [N || N <- lists:usort(Conectados), lists:member(N, Miembros)].
