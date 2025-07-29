最終更新：2025-07-29（JST）

対象環境
	•	Mac（ローカル）：/analysis（Git リポジトリ）、/bin（同期スクリプト）、~/Library/LaunchAgents（launchd）
	•	学校サーバ：/megraid01/users/takatsu_t/teto（この配下のみ操作可）
	•	NAS：/home/teto/mirror/megraid01/users/takatsu_t/teto（サーバと同構造でミラー）

保存場所（推奨）
	•	Mac：~/analysis/README.md
	•	学校サーバ：/megraid01/users/takatsu_t/teto/README.md
	•	保存後は Git にコミット・プッシュし、サーバ側で git pull してください。

――――――――――――――――――――
	1.	全体像（役割とデータフロー）

Mac（編集・Git・日次同期のトリガ）
→ 学校サーバ（ROOT マクロをバッチ実行、PNG/PDF 生成、catalog.csv 追記、ログ出力）
→ Mac（当日分の PNG/PDF・catalog を取得）
→ NAS（サーバと同じ階層構造でミラー）

標準フロー
	1.	Mac で編集して Git push
	2.	学校サーバで config/list.txt を用意して scripts/run_batch.sh を実行
	3.	Mac の日次スクリプト（23:40、自動）で当日分を NAS へミラー

――――――――――――――――――――
	2.	ディレクトリ構成

学校サーバ（/megraid01/users/takatsu_t/teto）
	•	src：ROOT マクロ（multi_draw_save.C など）
	•	scripts：run_batch.sh、weekly_maintenance.sh（任意）
	•	config：list.txt（処理対象リスト）
	•	plots：日付ディレクトリ（YYYY-MM-DD）ごとに PNG/PDF を保存。latest は最新日付へのシンボリックリンク
	•	results：catalog.csv（出力メタ情報を追記）
	•	logs：run_YYYY-MM-DD.log（実行ログ）

NAS（/home/teto/mirror/megraid01/users/takatsu_t/teto）
	•	サーバと同じ構造で PNG/PDF と catalog を保持
	•	必要に応じて plots/latest のリンクを作成可（任意）

Mac（~/analysis, ~/bin, ~/Library/LaunchAgents）
	•	リポジトリ（README.md, CMakeLists.txt, src など）
	•	日次同期スクリプト：~/bin/sync_day_pngpdf_to_nas.sh
	•	launchd 設定：~/Library/LaunchAgents/com.teto.syncpngpdf.plist（23:40 自動）

――――――――――――――――――――
	3.	主要スクリプト・ファイル（役割・PC・パス）

	•	バッチ実行（学校サーバ）：/megraid01/users/takatsu_t/teto/scripts/run_batch.sh
list.txt を読み、src/multi_draw_save.C を ROOT バッチで実行。plots/日付 に PNG/PDF を保存、results/catalog.csv に追記、logs/run_日付.log に記録。実行後に plots/latest を更新。
	•	描画マクロ（学校サーバ）：/megraid01/users/takatsu_t/teto/src/multi_draw_save.C
ROOT 6.32 互換版。TH1/TH2/TGraph/TCanvas を対象に描画保存。CSV に日時・入出力・ファイルサイズ・git commit を追記。
	•	日次同期（Mac）：~/bin/sync_day_pngpdf_to_nas.sh
指定日（既定は今日）の PNG/PDF と catalog.csv を、サーバ→Mac→NAS の二段 rsync でミラー。
	•	自動実行（Mac）：~/Library/LaunchAgents/com.teto.syncpngpdf.plist
23:40 に自動実行（RunAtLoad=true）。ログはユーザー設定のパスへ出力。
	•	週次メンテ（任意、学校サーバ）：/megraid01/users/takatsu_t/teto/scripts/weekly_maintenance.sh
30日超の logs 削除、古い plots/日付 ディレクトリをアーカイブして削除。Mac 側 launchd から週1で呼び出す運用が安全。

――――――――――――――――――――
	4.	list.txt の書式（2 形式に対応）

A. 現行フォーマット（スペース区切り）
	•	例1：/abs/path/to/file.root h1 h2 h3
	•	例2：/abs/path/to/file2.root（ヒスト名を省略すると TH1/TH2/TGraph/TCanvas を自動探索）

B. 旧フォーマット（セミコロン + カンマ）
	•	例：/abs/path/to/file.root; h1,h2,h3

注意
	•	行末などにインラインコメント（# 以降）を入れないでください。コメントは別行で記載してください。

――――――――――――――――――――
	5.	使い方（コマンド集）

5.1 学校サーバで一括描画（クリーンシェルでの実行を推奨）
	•	list.txt を編集
vi /megraid01/users/takatsu_t/teto/config/list.txt
	•	実行（ログイン設定の副作用回避）
bash –noprofile –norc -lc “/megraid01/users/takatsu_t/teto/scripts/run_batch.sh”
	•	確認
ls -l /megraid01/users/takatsu_t/teto/plots/$(date +%F) | head
tail -n 30 /megraid01/users/takatsu_t/teto/logs/run_$(date +%F).log
tail -n 5 /megraid01/users/takatsu_t/teto/results/catalog.csv

5.2 ヒスト名の確認（学校サーバ）
	•	対話
root -l /path/to/file.root
.ls
.q
	•	非対話（例）
root -l -b -q -e ‘TFile f(”/path/to/file.root”); f.ls(); gSystem->Exit(0);’

5.3 当日分を NAS に同期（Mac）
	•	今日
~/bin/sync_day_pngpdf_to_nas.sh
	•	任意の日付
~/bin/sync_day_pngpdf_to_nas.sh 2025-07-29
	•	NAS 側確認
ssh nas-lan “find /home/teto/mirror/megraid01/users/takatsu_t/teto/plots/$(date +%F) -maxdepth 1 -type f | sort | head”
ssh nas-lan “tail -n 5 /home/teto/mirror/megraid01/users/takatsu_t/teto/results/catalog.csv”

――――――――――――――――――――
	6.	ファイル仕様（要点）

multi_draw_save.C（学校サーバ）
	•	ROOT 6.32 対応：
	•	ファイルサイズ取得は TSystem::GetPathInfo(path, FileStat_t&) を使用
	•	日時は TDatime の AsSQLString を使用（YYYY-MM-DD HH:MM:SS）
	•	対象クラス：TH1、TH2、TGraph、TCanvas
	•	CSV 追記のヘッダ：date, file, obj, out_png, out_pdf, size_png, size_pdf, git_commit
	•	出力先：plots/YYYY-MM-DD/配下に、オブジェクトパスと同じ階層で png/pdf を保存

run_batch.sh（学校サーバ）
	•	冒頭で cd ${BASE} を実行し、相対パスの事故を防止
	•	list.txt はスペース区切り／セミコロン+カンマの両方に対応
	•	エラー発生時は即終了し、ログに [ERR] を出力
	•	実行後に plots/latest を最新日付へ更新

sync_day_pngpdf_to_nas.sh（Mac）
	•	GNU rsync（/opt/homebrew/bin/rsync）を使用
	•	サーバ→Mac は –relative を使って megraid01/…/plots/日付 の相対構造を保持
	•	Mac→NAS は相対パス（TMP 内の megraid01/… を起点）で送る（–relative は使わない）
	•	catalog.csv は最新版（catalog.csv）と日付スナップショット（catalog_YYYY-MM-DD.csv）の両方を NAS へ反映

――――――――――――――――――――
	7.	自動化（Mac / launchd）

	•	ラベル例：com.teto.syncpngpdf
	•	実行：毎日 23:40（StartCalendarInterval）、RunAtLoad=true
	•	PATH に依存しないようスクリプト内で rsync のフルパス（/opt/homebrew/bin/rsync）を明示

動作確認（例）
	•	launchctl list | grep com.teto.syncpngpdf
	•	launchctl kickstart -k gui/$(id -u)/com.teto.syncpngpdf
	•	tail -n 100 ~/tmp_plots/sync_stdout.log ~/tmp_plots/sync_stderr.log

――――――――――――――――――――
	8.	週次メンテ（任意）

	•	学校サーバの scripts/weekly_maintenance.sh を利用
30日超の logs を削除
30日超の plots/YYYY-MM-DD を archives/plots_YYYY-MM-DD.tar.gz にまとめてから削除
	•	実行（Mac から）
ssh school ‘/megraid01/users/takatsu_t/teto/scripts/weekly_maintenance.sh’

――――――――――――――――――――
	9.	トラブルシューティング

	•	macro … not found
run_batch.sh 実行時のカレントが teto/ ではない
対処：run_batch.sh 冒頭で cd ${BASE} を実行（現行版は対応済み）
	•	GetPathInfo / NowAsString のエラー
ROOT 6.32 の API 変更
対処：multi_draw_save.C は 6.32 互換版に修正済み
	•	NAS に日付ディレクトリが無い
Mac→NAS で –relative と絶対パスを併用し、/Users/… が転送された
対処：相対パスで送る（現行スクリプトは修正済み）
	•	zsh: command not found: #
同一行に # コメントを書いた
対処：コメントは別行で。特に ssh “printf …” の行末にコメントを付けない
	•	ログに which: invalid option
施設のログイン初期化の副作用
対処：クリーンシェルで実行（bash –noprofile –norc -lc “…”）
	•	Permission denied: run_batch.sh
実行権限なし
対処：chmod +x scripts/run_batch.sh

――――――――――――――――――――
	10.	初回セットアップ／更新時の手順

Mac
	•	README やスクリプトを更新
	•	git add README.md src/multi_draw_save.C scripts/run_batch.sh
	•	git commit -m “docs&batch: update README and batch pipeline”
	•	git push

学校サーバ
	•	cd /megraid01/users/takatsu_t/teto
	•	git pull
	•	chmod +x scripts/run_batch.sh scripts/weekly_maintenance.sh（存在する場合）

NAS
	•	特に操作不要（同期スクリプトがミラー）

――――――――――――――――――――
	11.	既知の前提・制約

	•	学校サーバのシステム設定は変更不可。/megraid01/users/takatsu_t/ 以下のみ操作可能
	•	ROOT は施設配布の 6.32.10 を利用
	•	Python 解析は当面対象外

――――――――――――――――――――
	12.	連絡先 / メモ

	•	改修提案や運用改善（VS Code Remote-SSH のタスク化、Slack 通知、週次メンテ自動化など）は随時
	•	以後、変更提案は「ファイル完全版」を提示・適用する方針

――――――――――――――――――――

付録 A：手早い確認ワンライナー
	•	今日 1 本だけ走らせる（学校サーバ）
bash –noprofile –norc -lc “/megraid01/users/takatsu_t/teto/scripts/run_batch.sh”
	•	NAS 反映の手動テスト（Mac）
~/bin/sync_day_pngpdf_to_nas.sh “$(date +%F)”
ssh nas-lan “find /home/teto/mirror/megraid01/users/takatsu_t/teto/plots/$(date +%F) -maxdepth 1 -type f | sort”
ssh nas-lan “tail -n 5 /home/teto/mirror/megraid01/users/takatsu_t/teto/results/catalog.csv”
