/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TosClient } from '../../../main/ets/client'
import {
  AK,
  SK,
  Endpoint,
  KMSMasterKeyID,
  MultiVersionBucket,
  TestBucket,
  Region,
  TestCallBackUrl
} from '../../../../env'
import { assertError, clearBucket, deleteBucket, genRandomId, getRandomLetter, log, writeFile } from './utils'
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { hashMd5, hashMd5ToStr, stringify } from '../../../main/ets/crypto';
import { buffer } from '@kit.ArkTS';

const client = new TosClient({
  accessKeyId: AK,
  accessKeySecret: SK,
  // securityToken: token,
  region: Region,
  endpoint: Endpoint,
});


export default function putObjectTest2() {
  let bucketName = genRandomId('put-object');
  describe('appendObjectTest', () => {
    beforeAll(async () => {
      log('before all buketName: ' + bucketName)
      await client.createBucket({
        Bucket: bucketName,
      })
    })
    afterAll(async () => {
      await deleteBucket(client, bucketName);
    })
    it('append_object_basic_usage', 0, async () => {
      const key = 'append-中文-많이드세요. 오늘내가쓸게요'
      let offset = 0;
      for (let i = 0; i < 5; i++) {
        const res = await client.appendObject({
          Bucket: bucketName,
          Key: key,
          Content: buffer.from(`${i}`).buffer,
          Offset: offset
        })
        offset = res.NextAppendOffset
        expect(res.HashCrc64ecma?.length && res.HashCrc64ecma.length > 0).assertTrue();
      };

      const res = await client.getObject({
        Bucket: bucketName,
        Key: key,
      })
      const content = res.Content.read(10);
      res.Content.close();
      expect(buffer.from(new Uint8Array(content)).toString('utf-8')).assertEqual('01234')
    })
    it('append_object_params', 0, async () => {
      const key = 'append_object_params';
      await client.appendObject({
        Bucket: bucketName,
        Key: key,
        Content: buffer.from(`abc`).buffer,
        Offset: 0,
        ContentDisposition: 'test123',
        ContentEncoding: 'utf',
        ContentLanguage: 'zh',
        ContentType: 'image/jpeg',
        Expires: new Date(Date.now()),
        // StorageClass: StorageClassType.StorageClassIa,
        Meta: {
          'k1': 'v1',
          'k2': '123',
          'k3': '你好',
          'test-窗前明月光': '疑似地上霜',
          '中文测试': 'value-中文测试'
        }
      })

      const res = await client.headObject({
        Bucket: bucketName,
        Key: key,
      })

      expect(res.ContentLength).assertEqual(3);
      expect(res.ContentDisposition).assertEqual('test123');
      expect(res.ContentEncoding).assertEqual('utf');
      expect(res.ContentLanguage).assertEqual('zh')
      expect(res.ContentType).assertEqual('image/jpeg');
      expect(res.Meta).assertDeepEquals({
        'k1': 'v1',
        'k2': '123',
        'k3': '你好',
        'test-窗前明月光': '疑似地上霜',
        '中文测试': 'value-中文测试'
      })
    })
  })
}