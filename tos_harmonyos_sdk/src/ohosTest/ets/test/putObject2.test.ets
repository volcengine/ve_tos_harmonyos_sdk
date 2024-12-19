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
  TestBucket,
  Region,
  TestCallBackUrl
} from '../../../../env'
import { assertError, clearBucket, deleteBucket, genRandomId, getRandomLetter, log, writeFile } from './utils'
import { hashMd5, hashMd5ToStr, stringify } from '../../../main/ets/crypto';
import { buffer } from '@kit.ArkTS';
import { StorageClassType, TosServerError } from '../../../../Index';

const client = new TosClient({
  accessKeyId: AK,
  accessKeySecret: SK,
  // securityToken: token,
  region: Region,
  endpoint: Endpoint,
});


export default function putObjectTest2() {
  let bucketName = genRandomId('put-object');
  describe('putObjectTest2', () => {
    beforeAll(async () => {
      log('before all buketName: ' + bucketName)
      await client.createBucket({
        Bucket: bucketName,
      })
    })
    afterAll(async () => {
      await deleteBucket(client, bucketName);
    })
    it('put_empty_object', 0, async () => {
      await client.putObject({
        Bucket: bucketName,
        Key: 'empty',
      })
      const res = await client.headObject({
        Bucket: bucketName,
        Key: 'empty',
      })
      expect(res.ContentLength).assertEqual(0)
    })
    it('put_object_callback', 0, async () => {
      const originInput = `
      {
        "callbackUrl" : "${TestCallBackUrl}",
        "callbackBody" : ${'"{\\"bucket\\": ${bucket}, \\"object\\": ${object}, \\"key1\\": ${x:key1}}"'},
        "callbackBodyType" : "application/json"
      }`;

      const originVarInput = `
      {
        "x:key1" : "ceshi"
      }`;
      const hashCallback = buffer.from(originInput).toString("base64");
      const hashCallbackVar = buffer.from(originVarInput).toString("base64");
      const res = await client.putObject({
        Bucket: TestBucket,
        Key: 'test',
        Callback: hashCallback,
        CallbackVar: hashCallbackVar,
      });
      expect(JSON.parse(res.CallbackResult ?? '')).assertDeepEquals({
        "message": "ok"
      })

      const errOriginVarInput = `
      {
        "x:key1" : aaaa
      }`;

      const errHashCallbackVar = buffer.from(errOriginVarInput).toString("base64");
      await assertError(async () => {
        await client.putObject({
          Bucket: TestBucket,
          Key: 'test',
          Callback: hashCallback,
          CallbackVar: errHashCallbackVar,
        });
      }, {
        callback(e){
          const err = e as TosServerError;
          expect(err.Code).assertEqual('InvalidCallbackArgument')
        }
      })
    })


    it('test-math-head-object', 0, async () => {
      const key = 'test-match.txt'
      await client.putObject({
        Bucket: TestBucket,
        Key: key,
        Content: buffer.from('test-match').buffer,
      })

      const res = await client.headObject({
        Bucket: TestBucket,
        Key: key,
      })
      const eTag = res.ETag;
      ;
      log('res' + eTag);
      const DiffTime = 1000 * 60 * 60;

      const matchHeadRes = await client.headObject({
        Bucket: TestBucket,
        Key: key,
        IfMatch: eTag,
        IfModifiedSince: new Date(Date.now() - DiffTime)
      })
      log('matchHeadRes' + matchHeadRes.StatusCode);
      expect(matchHeadRes.StatusCode).assertLess(300);

      await assertError(async () => {
        await client.headObject({
          Bucket: TestBucket,
          Key: key,
          IfMatch: 'abc'
        })
      }, {
        statusCode: 412
      })

      const notMatchHeadRes = await client.headObject({
        Bucket: TestBucket,
        Key: key,
        IfNoneMatch: 'abc',
        IfUnmodifiedSince: new Date(Date.now() + DiffTime)
      })
      log('notMatchHeadRes' + notMatchHeadRes.StatusCode);
      expect(notMatchHeadRes.StatusCode).assertLess(300);

      await assertError(async () => {
        await client.headObject({
          Bucket: TestBucket,
          Key: key,
          IfNoneMatch: eTag
        })
      }, {
        statusCode: 304
      })

      await assertError(async () => {
        await client.headObject({
          Bucket: TestBucket,
          Key: key,
          IfModifiedSince: new Date(Date.now() + DiffTime)
        })
      }, {
        statusCode: 304
      })

      await assertError(async () => {
        await client.headObject({
          Bucket: TestBucket,
          Key: key,
          IfUnmodifiedSince: new Date(Date.now() - DiffTime)
        })
      }, {
        statusCode: 412
      })
    })
    it('test-math-get-object', 0, async () => {
      const key = 'test-match.txt'
      await client.putObject({
        Bucket: TestBucket,
        Key: key,
        Content: buffer.from('test-match').buffer,
      })

      const res = await client.headObject({
        Bucket: TestBucket,
        Key: key,
      })
      const eTag = res.ETag;
      ;
      log('res' + eTag);
      const DiffTime = 1000 * 60 * 60;

      const matchHeadRes = await client.getObject({
        Bucket: TestBucket,
        Key: key,
        IfMatch: eTag,
        IfModifiedSince: new Date(Date.now() - DiffTime)
      })
      matchHeadRes.Content.close();
      log('matchHeadRes' + matchHeadRes.StatusCode);
      expect(matchHeadRes.StatusCode).assertLess(300);

      await assertError(async () => {
        await client.getObject({
          Bucket: TestBucket,
          Key: key,
          IfMatch: 'abc'
        })
      }, {
        statusCode: 412
      })

      const notMatchHeadRes = await client.getObject({
        Bucket: TestBucket,
        Key: key,
        IfNoneMatch: 'abc',
        IfUnmodifiedSince: new Date(Date.now() + DiffTime)
      })
      notMatchHeadRes.Content.close();
      log('notMatchHeadRes' + notMatchHeadRes.StatusCode);
      expect(notMatchHeadRes.StatusCode).assertLess(300);

      await assertError(async () => {
        await client.getObject({
          Bucket: TestBucket,
          Key: key,
          IfNoneMatch: eTag
        })
      }, {
        statusCode: 304
      })

      await assertError(async () => {
        await client.getObject({
          Bucket: TestBucket,
          Key: key,
          IfModifiedSince: new Date(Date.now() + DiffTime)
        })
      }, {
        statusCode: 304
      })

      await assertError(async () => {
        await client.getObject({
          Bucket: TestBucket,
          Key: key,
          IfUnmodifiedSince: new Date(Date.now() - DiffTime)
        })
      }, {
        statusCode: 412
      })
    })
    it('test-SSECKey-MD5', 0, async () => {
      const ssecKey = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const ssecMd5 = hashMd5ToStr(ssecKey, 'base64');
      await client.putObject({
        Bucket: TestBucket,
        Key: 'test-md5.txt',
        Content: buffer.from('123').buffer,
        SSECAlgorithm: 'AES256',
        SSECKey: stringify(new Uint8Array(buffer.from(ssecKey).buffer), 'base64'),
        SSECKeyMD5: ssecMd5,
      })

      const res = await client.headObject({
        Bucket: TestBucket,
        Key: 'test-md5.txt',
        SSECAlgorithm: 'AES256',
        SSECKey: stringify(new Uint8Array(buffer.from(ssecKey).buffer), 'base64'),
        SSECKeyMD5: ssecMd5,
      })
      expect(res.SSECKeyMD5).assertEqual(ssecMd5);
      expect(res.SSECAlgorithm).assertEqual('AES256');
      try {
        const res2 = await client.getObject({
          Bucket: TestBucket,
          Key: 'test-md5.txt',
          SSECAlgorithm: 'AES256',
          SSECKey: stringify(new Uint8Array(buffer.from(ssecKey).buffer), 'base64'),
          SSECKeyMD5: ssecMd5,
        })

        const content = stringify(new Uint8Array(res2.Content.read(1000)));
        expect(content).assertEqual('123');
        expect(res2.SSECKeyMD5).assertEqual(ssecMd5);
        expect(res2.SSECAlgorithm).assertEqual('AES256');
        res2.Content.close();
      } catch (e) {
        console.log(e);
      }
    })
    it('test-custom-header', 0, async () => {
      {
        const key = 'test-custom-header'
        await client.putObject({
          Key: key,
          Bucket: bucketName,
          RequestHeader: {
            'x-tos-storage-class': StorageClassType.StorageClassIa
          }
        })
        const res = await client.headObject({
          Key: key,
          Bucket: bucketName,
        })
        expect(res.StorageClass).assertEqual(StorageClassType.StorageClassIa);
      }

      {
        const key2 = 'test-custom-header2'
        await client.putObject({
          Key: key2,
          Bucket: bucketName,
          RequestHeader: {
            'X-Tos-Storage-Class': StorageClassType.StorageClassArchiveFr
          }
        })
        const res2 = await client.headObject({
          Key: key2,
          Bucket: bucketName,
        })
        expect(res2.StorageClass).assertEqual(StorageClassType.StorageClassArchiveFr);
      }
    })
  })
}