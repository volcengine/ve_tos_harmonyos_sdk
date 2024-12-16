# Torch Object Storage(TOS) HarmonyOS SDK
## 简介
Volcengine Object Storage(TOS) JS SDK 是火山引擎对象存储服务 TOS 提供的 JS 语言的接入SDK，为用户接入 TOS 提供便利的工具。
## Install
```shell
ohpm i @volcengine/tos_harmonyos_sdk
```
## Usage
``` typescript
import { TosClient, TosClientError, TosServerError } from 'tos_harmonyos_sdk';

// 创建客户端
const client = new TosClient({
  accessKeyId: "Provide your ak",
  accessKeySecret: "Provide your sk",
  region: "Provide your region", // 填写 Bucket 所在地域。以华北2（北京)为例，"Provide your region" 填写为 cn-beijing。
  endpoint: "Provide your endpoint", // 填写域名地址
});
// 存储桶名称
const bucketName = 'harmonyos-sdk-test-bucket';

function handleError(error: Error) {
  if (error instanceof TosClientError) {
    console.log('Client Err Msg:', error.message);
    console.log('Client Err Stack:', error.stack);
  } else if (error instanceof TosServerError) {
    console.log('Request ID:', error.requestId);
    console.log('Response Status Code:', error.statusCode);
    console.log('Response Header:', error.headers);
    console.log('Response Err Code:', error.code);
    console.log('Response Err Msg:', error.message);
  } else {
    console.log('unexpected exception, message: ', error);
  }
}

async function main() {
  try {
    // 创建桶
    await client.createBucket({
      Bucket: bucketName,
    });
    // 列举所有桶，将列举出刚刚创建的桶
    const { data } = await client.listBuckets();

    // `theBucket` 即为刚刚创建的桶
    const theBucket = data.Buckets.find(it => it.Name === bucketName);
    console.log('the bucket info', theBucket);
  } catch (error) {
    handleError(error);
  }
}

main();
```
## Changelog
Detailed changes for each release are documented in the CHANGELOG.md.