/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TosClient } from '../../../main/ets/client'
import { AK, SK, Endpoint, KMSMasterKeyID, MultiVersionBucket, TestBucket } from '../../../../env'
import { assertError, clearBucket,
  deleteBucket,
  genRandomId, getRandomLetter, log, specialCharKey, writeFile } from './utils'
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { hashMd5, hashMd5ToStr, hashSha256ToStr, stringify } from '../../../main/ets/crypto';
import { buffer } from '@kit.ArkTS';

const client = new TosClient({
  accessKeyId: AK,
  accessKeySecret: SK,
  // securityToken: token,
  region: Endpoint,
  endpoint: Endpoint,
});

export default function putObjectTest() {
  let bucketName = genRandomId('put-object');

  describe('put_object_test', () => {
    beforeAll(async () => {
      log('before all buketName: ' + bucketName)
      await client.createBucket({
        Bucket: bucketName,
      })
    })

    afterAll(async () => {
      await deleteBucket(client, bucketName);
    })

    it('put_object_test', 0, async () => {
      const bucketName = genRandomId('put-object');
      await client.createBucket({
        Bucket: bucketName,
      })
      const res = await client.putObject({
        Bucket: bucketName,
        Key: 'test.txt',
        Content: buffer.from('test123').buffer
      })

      expect(res.StatusCode).assertLess(300);
      expect(res.HashCrc64ecma && res.HashCrc64ecma.length > 0).assertTrue();
      log('res: ' + res.StatusCode);
      const res2 = await client.listObjectsType2({
        Bucket: bucketName,
      })
      expect(res2.Contents.some(c => c.Key === 'test.txt')).assertTrue();
      log('res2: ' + res2.StatusCode);
      const getObjectRes = await client.getObject({
        Bucket: bucketName,
        Key: 'test.txt'
      });
      const reader = getObjectRes.Content;
      let str = ''
      while (true) {
        const buf = reader.read(10000);
        str += stringify(new Uint8Array(buf))
        if (buf.byteLength === 0) {
          reader.close();
          break
        }
      }
      expect(str).assertEqual('test123');
      expect(getObjectRes.ContentLength).assertEqual(7)
      expect(getObjectRes.HashCrc64ecma && getObjectRes.HashCrc64ecma.length > 0).assertTrue();

      const res3 = await client.deleteObject({
        Bucket: bucketName,
        Key: 'test.txt',
      })
      log('res3: ' + res3.StatusCode);
      expect(res3.StatusCode).assertLess(300);
      expect(res3.DeleteMarker).assertFalse();
      const res4 = await client.listObjectsType2({
        Bucket: bucketName,
      })
      expect(res4.Contents.length).assertEqual(0);
      expect(res4.CommonPrefixes.length).assertEqual(0);

      const res5 = await client.deleteBucket({
        Bucket: bucketName,
      })
      expect(res5.StatusCode).assertLess(300);
    })
    it('put_object_special_character', 0, async () => {
      const objectKeys = [
        specialCharKey,
        '中文字符测试',
        'こんにちは',
        '안녕하세요'
      ]
      for (const key of objectKeys) {
        await client.putObject({
          Bucket: bucketName,
          Key: key,
          Content: buffer.from(key).buffer
        })
      }
      for (const key of objectKeys) {
        const res = await client.headObject({
          Bucket: bucketName,
          Key: key,
        })
        expect(res.ContentLength).assertLarger(0)
      }
      for (const key of objectKeys) {
        const res = await client.getObject({
          Bucket: bucketName,
          Key: key,
        })
        const content = res.Content.read(100);
        expect(stringify(new Uint8Array(content),'utf-8')).assertEqual(key)
      }
      for (const key of objectKeys) {
        const res = await client.listObjectsType2({
          Bucket: bucketName,
          Prefix: key
        })
        expect(res.Contents[0].Key).assertEqual(key)
      }
    })
    it('put_object_content_md5_sha256', 0, async () => {
      const totalSize = 3 * 1024 * 1024
      const buf = buffer.alloc(totalSize)
      const chunkSize = 1024;
      let offset = 0;

      for (let i = 0; i < 3 * 1024; i++) {
        buf.write(getRandomLetter(i).repeat(chunkSize), offset);
        offset += chunkSize
      }
      const contentMD5 = hashMd5ToStr(new Uint8Array(buf.buffer), 'base64');
      await assertError(async () => {
        await client.putObject({
          Bucket: TestBucket,
          Key:'test-content-md5-err',
          Content: buf.buffer,
          ContentMD5: 'abc',
        })
      }, {
        code: "InvalidDigest"
      })
      // expect(status).assertEqual(DataTransferType.Failed)
      await client.putObject({
        Bucket: TestBucket,
        Key:'test-content-md5',
        Content: buf.buffer,
        ContentMD5: contentMD5
      })
      const res = await client.headObject({
        Bucket: TestBucket,
        Key:'test-content-md5',
      })
      expect(res.ContentLength).assertEqual(totalSize);
    })
    it('put_object_content_sha256', 0, async () => {
      // const totalSize = 3 * 1024 * 1024
      // const buf = buffer.alloc(totalSize)
      // const chunkSize = 1024;
      // let offset = 0;
      //
      // for (let i = 0; i < 3 * 1024; i++) {
      //   buf.write(getRandomLetter(i).repeat(chunkSize), offset);
      //   offset += chunkSize
      // }
      const content = 'abc123456789kats?-='
      const contentSHA256 = hashSha256ToStr(content, 'hex');
      await assertError(async () => {
        await client.putObject({
          Bucket: TestBucket,
          Key:'test-content-md5-err',
          Content: buffer.from(content).buffer,
          ContentSHA256: 'abc'
        })
      }, {
        code: "ContentSHA256Mismatch"
      })
      // expect(status).assertEqual(DataTransferType.Failed)
      await client.putObject({
        Bucket: TestBucket,
        Key:'test-content-md5',
        Content: buffer.from(content).buffer,
        ContentSHA256: contentSHA256
      })
      const res = await client.headObject({
        Bucket: TestBucket,
        Key:'test-content-md5',
      })
      expect(res.ContentLength).assertEqual(content.length);
    })
    it('get_object_range_test', 0, async () => {
      const bucketName = genRandomId('put-object');
      await client.createBucket({
        Bucket: bucketName,
      })
      const str = '0123456789'
      await client.putObject({
        Bucket: bucketName,
        Key:'test',
        Content: buffer.from(str).buffer
      })
      const res = await client.getObject({
        Bucket: bucketName,
        Key:'test',
        RangeStart: 3,
      })
      const content = stringify(new Uint8Array(res.Content.read(100)));
      res.Content.close();
      expect(content).assertEqual(str.slice(3));

      const res3 = await client.getObject({
        Bucket: bucketName,
        Key:'test',
        RangeStart: 3,
        RangeEnd: 8,
      })
      expect(res3.ContentRange).assertEqual('bytes 3-8/10')
      expect(res3.ETag.length > 0).assertTrue()
      expect(res.ContentLength).assertEqual(7);
      const content3 = stringify(new Uint8Array(res3.Content.read(100)));
      res3.Content.close();
      expect(content3).assertEqual(str.slice(3, 9));
    })
    it('put_object_version_test', 0, async () => {
      const Prefix: string = 'put_object_version_test/';
      await clearBucket(client, MultiVersionBucket, Prefix);
      await client.putObject({
        Bucket: MultiVersionBucket,
        Key: Prefix + 'test.txt',
        Content: buffer.from('test123').buffer
      });
      const res = await client.listObjectVersions({
        Bucket: MultiVersionBucket,
        Prefix,
      });
      expect(res.Versions.length).assertEqual(1);
      const res2 = await client.headObject({
        Bucket: MultiVersionBucket,
        Key: res.Versions[0].Key,
        VersionID: res.Versions[0].VersionId
      })
      expect(res2.VersionID).assertEqual(res.Versions[0].VersionId);
      const res3 = await client.deleteObject({
        Bucket: MultiVersionBucket,
        Key: res.Versions[0].Key,
        VersionID: res.Versions[0].VersionId
      })
      expect(res3.VersionID).assertEqual(res.Versions[0].VersionId);
      expect(res3.DeleteMarker).assertFalse();
      const res4 = await client.listObjectVersions({
        Bucket: MultiVersionBucket,
        Prefix,
      });
      expect(res4.Versions.length).assertEqual(0);
    })
  })
}