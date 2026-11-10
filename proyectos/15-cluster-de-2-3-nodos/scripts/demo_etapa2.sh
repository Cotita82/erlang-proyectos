#!/bin/sh
# Demo de la Etapa 2: contador replicado, particion de red, caida del lider y
# regreso de un nodo sin datos, con 3 nodos reales + un nodo controlador (ctl).
# Ejecutar desde la carpeta del proyecto:  sh scripts/demo_etapa2.sh   (tarda ~1 min)
cd "$(dirname "$0")/.." || exit 1
rebar3 compile || exit 1
mkdir -p /tmp/p15demo
erlc -o /tmp/p15demo scripts/cluster_demo_etapa2.erl || exit 1
epmd -daemon   # los nodos necesitan epmd (puerto 4369) para descubrirse
pkill -f "beam.*n[123]@127.0.0.1" 2>/dev/null
erl -noshell -name ctl@127.0.0.1 \
  -kernel prevent_overlapping_partitions false \
  -pa _build/default/lib/p15_cluster_de_2_3_nodos/ebin \
  -pa /tmp/p15demo \
  -eval 'cluster_demo_etapa2:run(), halt().'
pkill -f "beam.*n[123]@127.0.0.1" 2>/dev/null
exit 0
