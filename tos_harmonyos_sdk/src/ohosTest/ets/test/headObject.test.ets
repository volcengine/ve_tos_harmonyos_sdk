/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TosClient } from '../../../main/ets/client'
import { AK, SK, Endpoint, KMSMasterKeyID } from '../../../../env'
import { assertError, genRandomId, log } from './utils'
import { GetBucketEncryptionOutput, StorageClassType } from '../../../../Index';
import { buffer, stream } from '@kit.ArkTS';

const client = new TosClient({
  accessKeyId: AK,
  accessKeySecret: SK,
  // securityToken: token,
  region: Endpoint,
  endpoint: Endpoint,
});

export default function headObjectTest() {
  let bucketName = genRandomId();
  beforeAll(async () => {
    log('before all')
    await client.createBucket({
      Bucket: bucketName,
    })
  })

  afterAll(async () => {
    try {
      await client.deleteBucket({
        Bucket: bucketName,
      })
      log('delete bucket success: ' + bucketName)
    } catch (e) {
      log('delete bucket error: ' + bucketName)
    }
  })

  describe('head_object_test', () => {
    it('head_objects_test', 0, async () => {
      const now = Date.now();
      await client.putObject({
        Bucket: bucketName,
        Key: 'test.txt',
        Content: buffer.from('test').buffer,
        ContentDisposition: 'test123',
        ContentEncoding: 'utf',
        ContentLanguage: 'zh',
        ContentType: 'image/jpeg',
        Expires: new Date(now),
        StorageClass: StorageClassType.StorageClassIa,
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
        Key: 'test.txt'
      })

      expect(res.ContentLength).assertEqual(4);
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
      expect(res.StorageClass).assertEqual(StorageClassType.StorageClassIa)
      expect(res.HashCrc64ecma?.length && res.HashCrc64ecma.length > 0).assertTrue();

      const getObjectRes = await client.getObject({
        Bucket: bucketName,
        Key: 'test.txt'
      })
      getObjectRes.Content.close();
      expect(getObjectRes.ETag).assertEqual(res.ETag);
      expect(getObjectRes.LastModified?.toString().length && getObjectRes.LastModified?.toString().length>0).assertTrue()
      log('get object last modify: ' + getObjectRes.LastModified?.toString())
      expect(getObjectRes.StorageClass).assertEqual(StorageClassType.StorageClassIa);
      expect(getObjectRes.Meta).assertDeepEquals({
        'k1': 'v1',
        'k2': '123',
        'k3': '你好',
        'test-窗前明月光': '疑似地上霜',
        '中文测试': 'value-中文测试'
      })
      expect(getObjectRes.ContentLength).assertEqual(4);
      expect(getObjectRes.ContentType).assertEqual('image/jpeg');
      expect(getObjectRes.ContentDisposition).assertEqual('test123');
      expect(getObjectRes.ContentEncoding).assertEqual('utf');
      expect(getObjectRes.ContentLanguage).assertEqual('zh')
      log('get object cache: ' +  getObjectRes.CacheControl);
      expect(getObjectRes.Expires?.toString().length && getObjectRes.Expires?.toString().length>0).assertTrue()
      log('get object expire: ' + getObjectRes.Expires?.toString())

      await client.setObjectMeta({
        Bucket: bucketName,
        Key: 'test.txt',
        ContentDisposition: 'test456',
        ContentEncoding: 'gzip',
        ContentLanguage: 'jap',
        ContentType: 'application/json',
        Expires: new Date(now),
        Meta: {
          'k1': 'v1',
          'k2': '123',
          'k3': '你好',
          'test-key有中文': 'value有中文',
          '中文测试': 'value-中文测试'
        }
      })
      const res2 = await client.headObject({
        Bucket: bucketName,
        Key: 'test.txt'
      })

      expect(res2.ContentLength).assertEqual(4);
      expect(res2.ContentDisposition).assertEqual('test456');
      expect(res2.ContentEncoding).assertEqual('gzip');
      expect(res2.ContentLanguage).assertEqual('jap')
      expect(res2.ContentType).assertEqual('application/json');
      expect(res2.Meta).assertDeepEquals({
        'k1': 'v1',
        'k2': '123',
        'k3': '你好',
        'test-key有中文': 'value有中文',
        '中文测试': 'value-中文测试'
      })
      await client.deleteObject({
        Bucket: bucketName,
        Key: 'test.txt'
      })
    })
  })
}