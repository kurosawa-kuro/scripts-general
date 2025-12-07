# AWS PoC Setup Scripts

PoC検証用にAWSリソースをサクッと用意するためのセットアップスクリプト集。

## 前提条件

- AWS CLI がインストール・設定済み
- 適切なIAM権限を持つ認証情報
- （推奨）jq コマンド

```bash
# AWS CLI確認
aws sts get-caller-identity

# jqインストール（Ubuntu）
sudo apt-get install jq
```

## スクリプト一覧

| スクリプト | 説明 |
|-----------|------|
| `setup-s3.sh` | S3バケット + サンプルファイル |
| `setup-cognito.sh` | Cognito User Pool + App Client + テストユーザー |
| `setup-dynamodb-table.sh` | DynamoDBテーブル + サンプルデータ |
| `setup-firehose-s3.sh` | Kinesis Firehose + S3配信先 + IAMロール |

---

## setup-s3.sh

S3バケットを作成し、サンプルファイルをアップロード。

```bash
./setup-s3.sh [BUCKET_NAME] [ENVIRONMENT]

# 例
./setup-s3.sh my-poc-bucket dev
```

### 作成されるリソース
- S3バケット（バージョニング有効、パブリックアクセスブロック）
- `sample/hello.txt` - テキストファイル
- `sample/config.json` - JSON設定例
- `sample/data.csv` - CSVデータ

### 環境変数
| 変数 | デフォルト | 説明 |
|------|-----------|------|
| `AWS_REGION` | ap-northeast-1 | AWSリージョン |

---

## setup-cognito.sh

Cognito User Poolとテストユーザーを作成。

```bash
./setup-cognito.sh [POOL_NAME] [ENVIRONMENT]

# 例
./setup-cognito.sh my-app-users dev
```

### 作成されるリソース
- User Pool（メール認証、パスワードポリシー設定済み）
- App Client（クライアントシークレットなし）
- テストユーザー（確認済み状態）

### 環境変数
| 変数 | デフォルト | 説明 |
|------|-----------|------|
| `AWS_REGION` | ap-northeast-1 | AWSリージョン |
| `TEST_USER_EMAIL` | test@example.com | テストユーザーのメール |
| `TEST_USER_PASSWORD` | TempPass123! | テストユーザーのパスワード |

### 出力例
```
User Pool ID:  ap-northeast-1_XXXXXXXXX
Client ID:     XXXXXXXXXXXXXXXXXXXXXXXXXX
Test User:     test@example.com
```

---

## setup-dynamodb-table.sh

DynamoDBテーブルを作成し、サンプルデータを投入。

```bash
./setup-dynamodb-table.sh [TABLE_NAME] [ENVIRONMENT]

# 例
./setup-dynamodb-table.sh my-table-dev dev
```

### 作成されるリソース
- DynamoDBテーブル（プロビジョンドキャパシティ）
- サンプルデータ3件（id, name, price, category, created_at）

### 環境変数
| 変数 | デフォルト | 説明 |
|------|-----------|------|
| `AWS_REGION` | ap-northeast-1 | AWSリージョン |
| `ATTRIBUTE_NAME` | id | プライマリキー名 |
| `ATTRIBUTE_TYPE` | N | キータイプ（N/S/B） |
| `READ_CAPACITY_UNITS` | 5 | 読み取りキャパシティ |
| `WRITE_CAPACITY_UNITS` | 5 | 書き込みキャパシティ |

---

## setup-firehose-s3.sh

Kinesis Data Firehoseを作成し、S3へのデータ配信環境を構築。

```bash
./setup-firehose-s3.sh [STREAM_NAME] [ENVIRONMENT]

# 例
./setup-firehose-s3.sh my-data-stream dev
```

### 作成されるリソース
- S3バケット（配信先）
- IAMロール + ポリシー（Firehose用）
- Firehose Delivery Stream（DirectPut、GZIP圧縮）
- テストレコード送信

### S3配信先パス
```
data/year=YYYY/month=MM/day=DD/
errors/[error-type]/year=YYYY/month=MM/day=DD/
```

### 環境変数
| 変数 | デフォルト | 説明 |
|------|-----------|------|
| `AWS_REGION` | ap-northeast-1 | AWSリージョン |
| `BUFFER_SIZE` | 5 | バッファサイズ（MB） |
| `BUFFER_INTERVAL` | 300 | バッファ間隔（秒） |

---

## 共通仕様

### 冪等性
- 既存リソースがある場合はスキップ
- データがない場合のみサンプルデータを投入

### 出力
- カラー出力で状態をわかりやすく表示
- `[OK]` 成功、`[ERROR]` エラー、`[WARN]` 警告、`[INFO]` 情報

### クリーンアップ
各スクリプト実行後に表示される削除コマンドを使用：

```bash
# S3
aws s3 rb s3://BUCKET_NAME --force

# Cognito
aws cognito-idp delete-user-pool --user-pool-id POOL_ID --region REGION

# DynamoDB
aws dynamodb delete-table --table-name TABLE_NAME --region REGION

# Firehose
aws firehose delete-delivery-stream --delivery-stream-name STREAM_NAME --region REGION
```
