/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TosClient } from '../../../main/ets/client'
import { AK, SK, Endpoint, KMSMasterKeyID, MultiVersionBucket } from '../../../../env'
import { assertError, clearBucket, deleteBucket, genRandomId, log, writeFile } from './utils'
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { hashMd5ToStr, stringify } from '../../../main/ets/crypto';
import { buffer } from '@kit.ArkTS';
import { MetadataDirectiveType, StorageClassType } from '../../../../Index';

export interface TestMeta extends Record<string, string> {
  k1: string;
  k2: string;
}

const client = new TosClient({
  accessKeyId: AK,
  accessKeySecret: SK,
  // securityToken: token,
  region: Endpoint,
  endpoint: Endpoint,
});

export default function copyObjectTest() {
  let sourceBucketName = genRandomId('copy-object-source')
  let targetBucketName = genRandomId('copy-object-target')
  beforeAll(async () => {
    await client.createBucket({
      Bucket: sourceBucketName,
    })
    log('create bucket success: ' + sourceBucketName)
    await client.createBucket({
      Bucket: targetBucketName,
    });
    log('create bucket success: ' + targetBucketName)
  })
  afterAll(async () => {
    await deleteBucket(client, sourceBucketName);
    await deleteBucket(client, targetBucketName);
  })
  describe('copy_object_test', () => {
    it('copy_object_basic_usage_test', 0, async () => {
      await client.putObject({
        Bucket: sourceBucketName,
        Key: 'test',
        Content: buffer.from('123').buffer
      })
      await client.copyObject({
        Bucket: targetBucketName,
        Key: 'test-copy',
        SrcBucket: sourceBucketName,
        SrcKey: 'test',
      })
      const res = await client.getObject({
          Bucket: targetBucketName,
          Key: 'test-copy',
      })
      const content = res.Content.read(10);
      res.Content.close()
      expect(stringify(new Uint8Array(content))).assertEqual('123');
    })
    it('test_copy_object_params', 0,async  () => {
      // storageClass
      await client.copyObject({
        Bucket: targetBucketName,
        Key: 'test-copy-storage-class',
        SrcBucket: sourceBucketName,
        SrcKey: 'test',
        StorageClass: StorageClassType.StorageClassIa
      })

      const res = await client.headObject({
        Bucket: targetBucketName,
        Key: 'test-copy-storage-class',
      })
      expect(res.StorageClass).assertEqual(StorageClassType.StorageClassIa);

      // meta
      const meta: TestMeta = {
        k1: 'v1',
        k2: 'v2'
      }

      const meta2: Record<string, string> = {
        'k1': 'v1',
        'k2': '123',
        'k3': '你好',
        'test-key有中文': 'value有中文',
        '中文测试': 'value-中文测试'
      }

      await client.setObjectMeta({
        Bucket: sourceBucketName,
        Key: 'test',
        Meta: meta,
      })

      await client.copyObject({
        Bucket: targetBucketName,
        Key: 'test-copy-meta',
        SrcBucket: sourceBucketName,
        SrcKey: 'test',
        MetadataDirective: MetadataDirectiveType.MetadataDirectiveCopy,
        Meta: meta2
      })

      const res2 = await client.headObject({
        Bucket: targetBucketName,
        Key: 'test-copy-meta',
      })
      expect(res2.Meta).assertDeepEquals(meta);

      // others
      await client.copyObject({
        Bucket: targetBucketName,
        Key: 'test-copy-others',
        SrcBucket: sourceBucketName,
        SrcKey: 'test',
        MetadataDirective: MetadataDirectiveType.MetadataDirectiveReplace,
        Meta: meta2,
        ContentDisposition: 'test123',
        ContentEncoding: 'utf',
        ContentLanguage: 'zh',
        ContentType: 'image/jpeg',
        Expires: new Date(Date.now()),
      })

      const res3 = await client.headObject({
        Bucket: targetBucketName,
        Key: 'test-copy-others',
      })
      expect(res3.ContentDisposition).assertEqual('test123');
      expect(res3.ContentEncoding).assertEqual('utf');
      expect(res3.ContentLanguage).assertEqual('zh')
      expect(res3.ContentType).assertEqual('image/jpeg');
      expect(res3.Meta).assertDeepEquals(meta2)

      // ssec
      const ssecKey = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const ssecMd5 = hashMd5ToStr(ssecKey, 'base64');
      const copyRes = await client.copyObject({
        Bucket: sourceBucketName,
        Key: 'test-copy-object-ssec',
        SrcBucket: sourceBucketName,
        SrcKey: 'test',
        SSECAlgorithm: 'AES256',
        SSECKey: stringify(new Uint8Array(buffer.from(ssecKey).buffer), 'base64'),
        SSECKeyMD5: ssecMd5,
      })
      expect(copyRes.SSECAlgorithm).assertEqual('AES256');
      expect(copyRes.SSECKeyMD5).assertEqual(ssecMd5);

      await assertError(async () => {
        await client.getObject({
          Bucket: sourceBucketName,
          Key: 'test-copy-object-ssec',
        })
      })

      const res4 = await client.headObject({
        Bucket: sourceBucketName,
        Key: 'test-copy-object-ssec',
        SSECAlgorithm: 'AES256',
        SSECKey: stringify(new Uint8Array(buffer.from(ssecKey).buffer), 'base64'),
        SSECKeyMD5: ssecMd5,
      })
      expect(res4.SSECAlgorithm).assertEqual('AES256');
      expect(res4.SSECKeyMD5).assertEqual(ssecMd5);
      expect(res4.ETag).assertEqual(copyRes.ETag);
    })

    it('test_copy_source_ssec', 0, async () => {
      // ssec
      const ssecKey = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const ssecMd5 = hashMd5ToStr(ssecKey, 'base64');
      await client.putObject({
        Bucket: sourceBucketName,
        Key: 'test-ssec-source',
        Content: buffer.from('123').buffer,
        SSECAlgorithm: 'AES256',
        SSECKey: stringify(new Uint8Array(buffer.from(ssecKey).buffer), 'base64'),
        SSECKeyMD5: ssecMd5,
      });
      await assertError(async () => {
        await client.copyObject({
          Bucket: targetBucketName,
          Key: 'test-ssec-target',
          SrcBucket: sourceBucketName,
          SrcKey: 'test-ssec-source',
        })
      })

      await client.copyObject({
        Bucket: targetBucketName,
        Key: 'test-ssec-target',
        SrcBucket: sourceBucketName,
        SrcKey: 'test-ssec-source',
        CopySourceSSECAlgorithm: 'AES256',
        CopySourceSSECKey: stringify(new Uint8Array(buffer.from(ssecKey).buffer), 'base64'),
        CopySourceSSECKeyMD5: ssecMd5,
      })
    })

    it('test_copy_object_version', 0, async () => {
      const prefix = 'test_copy_object_version/'
      const key = prefix + 'test'
      await client.putObject({
        Bucket: MultiVersionBucket,
        Key: key,
        Content: buffer.from('123').buffer
      })

      await client.putObject({
        Bucket: MultiVersionBucket,
        Key: key,
        Content: buffer.from('123').buffer
      })

      const res = await client.listObjectVersions({
        Bucket: MultiVersionBucket,
      })

      const versionId = res.Versions.find(item => item.VersionId !== 'null' && item.Key === key)?.VersionId;
      if (!versionId) {
        expect(true).assertFalse();
      }

      const res2 = await client.copyObject({
        Bucket: MultiVersionBucket,
        Key: prefix + 'test2',
        SrcBucket: MultiVersionBucket,
        SrcKey: key,
        SrcVersionID: versionId
      })
      expect(versionId).assertEqual(res2.CopySourceVersionID);
      // expect(res2.VersionID?.length).assertLarger(0);
    })
  })
}