/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TosClient } from '../../../main/ets/client'
import { AK, SK, Endpoint, KMSMasterKeyID, MultiVersionBucket, TestBucket } from '../../../../env'
import { assertError, clearBucket, deleteBucket, genRandomId, getRandomLetter, log, writeFile } from './utils'
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { hashMd5, hashMd5ToStr, stringify } from '../../../main/ets/crypto';
import { buffer } from '@kit.ArkTS';
import { ACLType, StorageClassType, TosServerError } from '../../../../Index';

const client = new TosClient({
  accessKeyId: AK,
  accessKeySecret: SK,
  // securityToken: token,
  region: Endpoint,
  endpoint: Endpoint,
});

export default function fetchObjectTest() {
  let bucketName = genRandomId('fetch-task');
  const oldKey = `fetchObject-oldKey`;
  const content = 'fetch_task_test';
  const contentMd5 = hashMd5ToStr(content, 'base64');
  let url = ''
  const md5 = hashMd5ToStr(content, 'base64');
  describe('fetch_task_test', () => {
    beforeAll(async () => {
      log('before all buketName: ' + bucketName)
      await client.createBucket({
        Bucket: bucketName,
      })
      await client.putObject({
        Bucket: bucketName,
        Key: oldKey,
        Content: buffer.from(content).buffer,
      });
      const res = await client.preSignedURL({
        Bucket: bucketName,
        Key: oldKey,
      })
      url = res.SignedUrl;
    })
    afterAll(async () => {
      await deleteBucket(client, bucketName);
    })
    it('fetch_task_basic_use', 0, async () => {
      const key = 'key' + Math.floor(Math.random() * 10) + '.txt'
      log('key: ' + key)
      const res = await client.putFetchTask({
        Bucket: TestBucket,
        Key: key,
        URL: url,
      })
      expect(res.TaskId.length > 0).assertTrue();
      const res2 = await client.getFetchTask({
        Bucket: TestBucket,
        TaskID: res.TaskId,
      })
      expect(res2.Task.URL).assertEqual(url);
      expect(res2.Task.Bucket).assertEqual(TestBucket);
      expect(res2.Task.Object).assertEqual(key);
    })
    it('fetch_task_IgnoreSameKey', 0, async () => {
      const key = 'fetch_task_IgnoreSameKey_key' + Math.floor(Math.random() * 10) + '.txt'
      log('key: ' + key)
      await client.putObject({
        Bucket: TestBucket,
        Key: key
      })
      const res = await client.putFetchTask({
        Bucket: TestBucket,
        Key: key,
        URL: url,
        IgnoreSameKey: true,
      })
      const res2 = await client.getFetchTask({
        Bucket: TestBucket,
        TaskID: res.TaskId,
      })
      expect(res2.Task.URL).assertEqual(url);
      expect(res2.Task.Bucket).assertEqual(TestBucket);
      expect(res2.Task.Object).assertEqual(key);
      expect(res2.Task.IgnoreSameKey).assertTrue();
    })
    it('fetch_task_content_md5', 0, async () => {
      const key = 'fetch_task_content_md5' + Math.floor(Math.random() * 10) + '.txt'
      log('key: ' + key)
      await client.putObject({
        Bucket: TestBucket,
        Key: key
      })
      const res = await client.putFetchTask({
        Bucket: TestBucket,
        Key: key,
        URL: url,
        ContentMD5: contentMd5,
      })
      const res2 = await client.getFetchTask({
        Bucket: TestBucket,
        TaskID: res.TaskId,
      })
      expect(res2.Task.URL).assertEqual(url);
      expect(res2.Task.Bucket).assertEqual(TestBucket);
      expect(res2.Task.Object).assertEqual(key);
      expect(res2.Task.ContentMD5).assertEqual(contentMd5);
    })
    it('fetch_task_other_params', 0 , async () => {
      const key = 'fetch_task_other_params'+ Math.floor(Math.random() * 10) + '.txt';
      const ssecKey = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const ssecMd5 = hashMd5ToStr(ssecKey, 'base64');
      const res = await client.putFetchTask({
        Bucket: TestBucket,
        Key: key,
        URL: url,
        StorageClass: StorageClassType.StorageClassIa,
        SSECAlgorithm: 'AES256',
        SSECKey: stringify(new Uint8Array(buffer.from(ssecKey).buffer), 'base64'),
        SSECKeyMD5: ssecMd5,
        Meta: {
          'k1': 'v1',
          'k2': '123',
          'k3': '你好'
        }
      })
      const res2 = await client.getFetchTask({
        Bucket: TestBucket,
        TaskID: res.TaskId
      })
      expect(res2.Task.URL).assertEqual(url);
      expect(res2.Task.Bucket).assertEqual(TestBucket);
      expect(res2.Task.Object).assertEqual(key);
      expect(res2.Task.StorageClass).assertEqual(StorageClassType.StorageClassIa);
      expect(res2.Task.SSECAlgorithm).assertEqual('AES256');
      expect(res2.Task.SSECKey).assertEqual(stringify(new Uint8Array(buffer.from(ssecKey).buffer), 'base64'));
      expect(res2.Task.Meta).assertDeepEquals({
        'k1': 'v1',
        'k2': '123',
        'k3': '你好'
      })
    })
  })
}