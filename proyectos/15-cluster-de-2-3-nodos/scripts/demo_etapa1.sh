#!/bin/sh
# Compila el proyecto y corre la demo de 3 nodos reales (Etapa 1).
# Ejecutar desde la carpeta del proyecto:  sh scripts/demo_etapa1.sh
cd "$(dirname "$0")/.." || exit 1
rebar3 compile || exit 1
mkdir -p /tmp/p15demo
erlc -o /tmp/p15demo scripts/cluster_demo.erl || exit 1
epmd -daemon   # los nodos necesitan epmd (puerto 4369) para descubrirse
pkill -f "beam.*n[23]@127.0.0.1" 2>/dev/null
erl -noshell \
  -pa _build/default/lib/p15_cluster_de_2_3_nodos/ebin \
  -pa /tmp/p15demo \
  -eval 'cluster_demo:run(), halt().'
pkill -f "beam.*n[23]@127.0.0.1" 2>/dev/null
exit 0
