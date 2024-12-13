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
  let bucketName = genRandomId('fetch-object');
  let bucketName2 = genRandomId('fetch-object');
  const oldKey = `fetchObject-oldKey`;
  const content = Math.random().toFixed(100);
  const md5 = hashMd5ToStr(content, 'base64');
  describe('fetch_object_test', () => {
    beforeAll(async () => {
      log('before all buketName: ' + bucketName)
      await client.createBucket({
        Bucket: bucketName,
      })
      await client.createBucket({
        Bucket: bucketName2,
      })
      await client.putObject({
        Bucket: bucketName2,
        Key: oldKey,
        Content: buffer.from(content).buffer,
      });
    })
    afterAll(async () => {
      await deleteBucket(client, bucketName);
      await deleteBucket(client, bucketName2);
    })

    it('fetch_object', 0, async () => {
      const key = `fetchObject-${Math.random()}`;
      const signedRes = await client.preSignedURL({
        Bucket: bucketName2,
        Key: oldKey,
      });
      const meta: Record<string, string> = {}
      meta.abc = '123';
      const res = await client.fetchObject({
        Bucket: bucketName,
        URL: signedRes.SignedUrl,
        Key: key,
        ACL: ACLType.ACLPublicRead,
        Meta: meta,
      });
      expect(res.ETag.length > 0).assertTrue();
      const res2 = await client.headObject({
        Bucket: bucketName,
        Key: key,
      })
      expect(res2.Meta).assertDeepEquals(meta);
    })
    it('fetch_objec_with_MD5', 0, async () => {
      const key = `fetchObject-${Math.random()}`;
      const signedRes = await client.preSignedURL({
        Bucket: bucketName2,
        Key: oldKey,
      });
      const res = await client.fetchObject({
        Bucket: bucketName,
        Key: key,
        URL: signedRes.SignedUrl,
        ContentMD5: md5,
      })
      expect(res.ETag.length > 0).assertTrue();
    })
    it('fetch_object_with_wrong_MD5', 0, async () => {
      const key = `fetchObject-${Math.random()}`;
      await client.putObject({
        Bucket: bucketName2,
        Key: oldKey,
        Content: buffer.from(content).buffer,
      });
      const signedRes = await client.preSignedURL({
        Bucket: bucketName2,
        Key: oldKey,
      });
      await assertError(async () => {
        await client.fetchObject({
          Bucket: bucketName,
          Key: key,
          URL: signedRes.SignedUrl,
          ContentMD5: 'abc',
        })
      }, {
        callback(e){
          const err2 = e as TosServerError;
          expect(err2.Code).assertEqual('InvalidArgument')
        }
      })
    })
    it('fetch_object_the_exist_key', 0 , async () => {
      const existKey = `fetchObject-exist-${Math.random()}`;
      await client.putObject({
        Bucket: bucketName,
        Key: existKey,
        Content: buffer.from('123').buffer
      })
      const signedRes = await client.preSignedURL({
        Bucket: bucketName2,
        Key: oldKey,
      });
      await assertError(async () => {
        await client.fetchObject({
          Bucket: bucketName,
          Key: existKey,
          URL: signedRes.SignedUrl,
          IgnoreSameKey: true,
        })
      }, {
        callback(e){
          const err2 = e as TosServerError;
          expect(err2.Code).assertEqual('DuplicateObject');
        }
      })

      await client.fetchObject({
        Bucket: bucketName,
        Key: existKey,
        URL: signedRes.SignedUrl,
        IgnoreSameKey: false,
        StorageClass: StorageClassType.StorageClassIa
      })
      const res = await client.headObject({
        Bucket: bucketName,
        Key: existKey,
      })
      expect(res.StorageClass).assertEqual(StorageClassType.StorageClassIa)
    })
    it('fetch_object_ssec', 0, async () => {
      const key = `fetchObject-${Math.random()}`;
      const signedRes = await client.preSignedURL({
        Bucket: bucketName2,
        Key: oldKey,
      });
      const ssecKey = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const ssecMd5 = hashMd5ToStr(ssecKey, 'base64');
      const res = await client.fetchObject({
        Bucket: bucketName,
        Key: key,
        URL: signedRes.SignedUrl,
        SSECAlgorithm: 'AES256',
        SSECKey: stringify(new Uint8Array(buffer.from(ssecKey).buffer), 'base64'),
        SSECKeyMD5: ssecMd5,
      })
      expect(res.SSECAlgorithm).assertEqual('AES256')
      expect(res.SSECKeyMD5).assertEqual(ssecMd5)
      await assertError(async ()=> {
        await client.headObject({
          Bucket: bucketName,
          Key: key,
        })
      }, {
        callback(e){
          const err2 = e as TosServerError;
          expect(err2.RequestID.length > 0).assertTrue();
        }
      })
      const res2 = await client.headObject({
        Bucket: bucketName,
        Key: key,
        SSECAlgorithm: 'AES256',
        SSECKey: stringify(new Uint8Array(buffer.from(ssecKey).buffer), 'base64'),
        SSECKeyMD5: ssecMd5,
      })
      expect(res2.ETag.length > 0).assertTrue();
    })
  })
}