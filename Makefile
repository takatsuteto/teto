# Makefile — pull→run→sync→確認（DATE を指定可）
SHELL := /bin/bash
DATE ?= $(shell date +%F)

.PHONY: run sync check all

run:
	@ssh school 'bash --noprofile --norc -lc "/megraid01/users/takatsu_t/teto/scripts/run_batch.sh"'

sync:
	@~/bin/sync_day_pngpdf_to_nas.sh $(DATE)

check:
	@ssh school "tail -n 10 /megraid01/users/takatsu_t/teto/logs/run_$(DATE).log || true"
	@ssh nas-lan "find /home/teto/mirror/megraid01/users/takatsu_t/teto/plots/$(DATE) -maxdepth 1 -type f | sort || true"

all: run sync check
