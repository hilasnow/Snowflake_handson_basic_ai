-- =============================================================
-- test.sql
-- 金融バナー広告 AI分析 動作確認用
--
-- 概要:
--   part3 用バナー画像 (ad_001.png ~ ad_008.png) を
--   ステージにロードし、AI_COMPLETE でクリエイティブ特徴を
--   JSON 構造で抽出するテスト。
--
-- 前提:
--   setup.sql 実行済み (GLACIERSTYLE_DB / EC_ANALYTICS_SCHEMA / DATA_STAGE)
--   images/part3/ に ad_001.png ~ ad_008.png が存在すること
-- =============================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE GLACIERSTYLE_DB;
USE SCHEMA EC_ANALYTICS_SCHEMA;
USE WAREHOUSE GLACIERSTYLE_WH;

-- -----------------------------------------------
-- Step 1: 画像をステージにコピー
--   ワークスペースから ad_001.png ~ ad_008.png を
--   @DATA_STAGE へコピーする。
--   ※ ステージは setup.sql で作成済み (DIRECTORY = (ENABLE = TRUE))
-- -----------------------------------------------

COPY FILES INTO @DATA_STAGE
  FROM 'snow://workspace/USER$.PUBLIC."Snowflake_handson_basic_ai"/versions/live/'
  PATTERN = 'images/part3/ad_.*[.]png';

-- ディレクトリを更新
ALTER STAGE DATA_STAGE REFRESH;

-- アップロード確認 (8件あること)
SELECT relative_path, size
FROM DIRECTORY(@DATA_STAGE)
WHERE relative_path LIKE 'images/part3/ad_%.png'
ORDER BY relative_path;

-- -----------------------------------------------
-- Step 2: 1枚テスト (ad_001.png)
--   AI_COMPLETE で金融バナーの5特徴を抽出する。
--   まずここで JSON が正しく返ってくるか確認。
-- -----------------------------------------------

SELECT
  relative_path,
  PARSE_JSON(
    REGEXP_REPLACE(
      AI_COMPLETE(
        'claude-sonnet-4-6',
        PROMPT(
          $$以下の金融広告バナー画像を分析して、JSON形式で結果を返してください。
JSONオブジェクトのみ返してください。説明文やコードブロック記法は不要です。

has_person: true or false
  -- 広告バナーに人物（顔・体・手など身体の一部）が写っているか
color_tone: "暖色系" or "寒色系" or "パステル" or "モノトーン"
  -- 画像全体の色調。赤・オレンジ・黄は暖色系、青・紺・緑は寒色系、淡い色はパステル、白黒・グレー系はモノトーン
has_chart_or_graph: true or false
  -- バナーにグラフ・チャート・表・数値推移図などのデータビジュアライゼーションが含まれるか
image_complexity: "シンプル" or "標準" or "複雑"
  -- シンプル: テキストと要素が少なく一目でわかる構成
  -- 複雑: グラフ・表・複数のテキストブロックなど情報要素が多い構成
main_color: "青" or "緑" or "赤" or "グレー" or "黒" or "オレンジ" or "ネイビー" or "その他"
  -- 背景や最も面積の大きい色

画像: {0}$$,
          TO_FILE('@DATA_STAGE', relative_path)
        )
      ),
      '^[^{]*|[^}]*$', ''
    )
  ) AS features_json
FROM DIRECTORY(@DATA_STAGE)
WHERE relative_path = 'images/part3/ad_001.png';

-- -----------------------------------------------
-- Step 3: 全 8 枚一括分析 → テーブル保存
--   JSON 展開まで一発で CTAS する。
--   ※ AI_COMPLETE が 8 回実行されるので数秒かかる。
-- -----------------------------------------------

CREATE OR REPLACE TABLE gold_ad_image_analysis AS
SELECT
  REGEXP_SUBSTR(relative_path, 'ad_[0-9]+[.]png$') AS image_file,
  relative_path,
  PARSE_JSON(
    REGEXP_REPLACE(
      AI_COMPLETE(
        'claude-sonnet-4-6',
        PROMPT(
          $$以下の金融広告バナー画像を分析して、JSON形式で結果を返してください。
JSONオブジェクトのみ返してください。説明文やコードブロック記法は不要です。

has_person: true or false
  -- 広告バナーに人物（顔・体・手など身体の一部）が写っているか
color_tone: "暖色系" or "寒色系" or "パステル" or "モノトーン"
  -- 画像全体の色調。赤・オレンジ・黄は暖色系、青・紺・緑は寒色系、淡い色はパステル、白黒・グレー系はモノトーン
has_chart_or_graph: true or false
  -- バナーにグラフ・チャート・表・数値推移図などのデータビジュアライゼーションが含まれるか
image_complexity: "シンプル" or "標準" or "複雑"
  -- シンプル: テキストと要素が少なく一目でわかる構成
  -- 複雑: グラフ・表・複数のテキストブロックなど情報要素が多い構成
main_color: "青" or "緑" or "赤" or "グレー" or "黒" or "オレンジ" or "ネイビー" or "その他"
  -- 背景や最も面積の大きい色

画像: {0}$$,
          TO_FILE('@DATA_STAGE', relative_path)
        )
      ),
      '^[^{]*|[^}]*$', ''
    )
  ) AS features_json,
  features_json:has_person::BOOLEAN         AS has_person,
  features_json:color_tone::VARCHAR         AS color_tone,
  features_json:has_chart_or_graph::BOOLEAN AS has_chart_or_graph,
  features_json:image_complexity::VARCHAR   AS image_complexity,
  features_json:main_color::VARCHAR         AS main_color
FROM DIRECTORY(@DATA_STAGE)
WHERE relative_path LIKE 'images/part3/ad_%.png'
ORDER BY relative_path;

-- -----------------------------------------------
-- Step 4: 結果確認
-- -----------------------------------------------

SELECT * FROM gold_ad_image_analysis ORDER BY image_file;
