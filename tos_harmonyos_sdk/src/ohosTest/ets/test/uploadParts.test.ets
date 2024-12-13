/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TosClient } from '../../../main/ets/client'
import { AK, SK, Endpoint, KMSMasterKeyID, MultiVersionBucket, TestBucket, AccountId, TestCallBackUrl } from '../../../../env'
import { assertError, clearBucket,
  deepAssertStrList,
  deleteBucket, genRandomId, getRandomLetter, log, writeFile } from './utils'
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { hashMd5, hashMd5ToStr, stringify } from '../../../main/ets/crypto';
import { buffer } from '@kit.ArkTS';
import { StorageClassType, TosServerError } from '../../../../Index';
import { ListedUpload, UploadedPart } from '../../../main/ets/types/model2';


const client = new TosClient({
  accessKeyId: AK,
  accessKeySecret: SK,
  // securityToken: token,
  region: Endpoint,
  endpoint: Endpoint,
});
export default function uploadPartsTest(){
  let bucketName = TestBucket//genRandomId('parts');

  describe('upload_parts_test', () => {
    beforeAll(async () => {
      log('before all buketName: ' + bucketName)
      await client.createBucket({
        Bucket: bucketName,
      })
    })
    afterAll(async () => {
      await deleteBucket(client, bucketName)
    })

    it('basic_usage', 0, async () => {
      const chunkSize = 20 * 1024 * 1024;
      const count = 3;
      const res = await client.createMultipartUpload({
        Bucket: bucketName,
        Key: 'test-upload-parts'
      })
      log('create MultipartUpload success')
      for (let i = 1; i < count + 1; i++) {
        const chunk = buffer.from(getRandomLetter(i).repeat(chunkSize)).buffer
        const res2 = await client.uploadPart({
          Bucket: bucketName,
          Key: 'test-upload-parts',
          UploadID: res.UploadId,
          PartNumber: i,
          Content: chunk
        })
        expect(res2.PartNumber).assertEqual(i);
        expect(res2.ETag.length > 0).assertTrue()
      }
      const res3 = await client.completeMultipartUpload({
        Bucket: bucketName,
        Key: 'test-upload-parts',
        UploadID: res.UploadId,
        CompleteAll: true,
      })
      expect(res3.Bucket).assertEqual(bucketName);
      expect(res3.ETag.length > 0).assertTrue();
      expect(res3.Location.length > 0).assertTrue();
      expect(res3.CompletedParts?.length).assertEqual(3);
      const res4 = await client.headObject({
        Bucket: bucketName,
        Key: 'test-upload-parts',
      })
      expect(res4.ContentLength).assertEqual(count * chunkSize);
    })
    it('upload_part_content5', 0, async () => {
      const chunkSize = 4 * 1024 * 1024;
      const res = await client.createMultipartUpload({
        Bucket: bucketName,
        Key: 'test-upload-parts'
      })
      const chunk = buffer.from(getRandomLetter(0).repeat(chunkSize)).buffer;
      const contentMd5 = hashMd5ToStr(new Uint8Array(chunk), 'base64');
      await client.uploadPart({
        Bucket: bucketName,
        Key: 'test-upload-parts',
        UploadID: res.UploadId,
        PartNumber: 1,
        Content: chunk,
        ContentMD5: contentMd5
      })
      await assertError(async () => {
        await client.uploadPart({
          Bucket: bucketName,
          Key: 'test-upload-parts',
          UploadID: res.UploadId,
          PartNumber: 2,
          Content: chunk,
          ContentMD5: '111',
        })
      }, {
        callback(err){
          const err2 = err as TosServerError;
          expect(err2.Code).assertEqual('BadDigest');
        }
      })
    })
    it('list_parts', 0, async () => {
      const key = 'test-list_parts'
      const chunkSize = 4 * 1024 * 1024;
      const count = 5;
      const res = await client.createMultipartUpload({
        Bucket: bucketName,
        Key: key
      })
      const parts: UploadedPart[] = [];
      for (let i = 1; i < count + 1; i++) {
        const chunk = buffer.from(getRandomLetter(i).repeat(chunkSize)).buffer
        const res2 = await client.uploadPart({
          Bucket: bucketName,
          Key: key,
          UploadID: res.UploadId,
          PartNumber: i,
          Content: chunk
        })
        expect(res2.PartNumber).assertEqual(i);
        expect(res2.ETag.length > 0).assertTrue()
        parts.push(new UploadedPart(res2.PartNumber, res2.ETag));
      }
      const res2 = await client.listParts({
        Bucket: bucketName,
        Key: key,
        UploadId: res.UploadId
      })
      expect(res2.Bucket).assertEqual(bucketName);
      expect(res2.Key).assertEqual(key);
      expect(res2.UploadId).assertEqual(res.UploadId);
      expect(res2.StorageClass).assertEqual(StorageClassType.StorageClassStandard);
      expect(res2.Owner.ID).assertEqual(AccountId);
      expect(res2.Parts.length).assertEqual(5);

      let partNumberMarker: number | undefined
      let ids2: string[] = [];
      while (true) {
        const res3 = await client.listParts({
          Bucket: bucketName,
          Key: key,
          UploadId: res.UploadId,
          MaxParts: 4,
          PartNumberMarker: partNumberMarker,
        })
        expect(res3.MaxParts).assertEqual(4);
        ids2 = ids2.concat(res3.Parts.map(item => String(item.PartNumber)));
        if (!res3.IsTruncated) {
          break;
        }
        partNumberMarker = res3.NextPartNumberMarker;
      }
      expect(ids2.length).assertEqual(count)
      deepAssertStrList(ids2, new Array(count).fill(0).map((_: number, index) => String(index)))
      await client.completeMultipartUpload({
        Bucket: bucketName,
        Key: key,
        UploadID: res.UploadId,
        Parts: parts
      })
      const res5 = await client.headObject({
        Bucket: bucketName,
        Key: key
      })
      expect(res5.ContentLength).assertEqual(count * chunkSize)
    })
    it('complete_part_callback', 0, async () => {
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

      const hashCallback = buffer.from(originInput).toString('base64');
      const hashCallbackVar = buffer.from(originVarInput).toString('base64');
      const chunkSize = 4 * 1024 * 1024;
      const count = 3;
      const key = 'test-upload-callback'
      const res = await client.createMultipartUpload({
        Bucket: bucketName,
        Key: key
      })
      for (let i = 1; i < count + 1; i++) {
        const chunk = buffer.from(getRandomLetter(i).repeat(chunkSize)).buffer
        const res2 = await client.uploadPart({
          Bucket: bucketName,
          Key: key,
          UploadID: res.UploadId,
          PartNumber: i,
          Content: chunk
        })
        expect(res2.PartNumber).assertEqual(i);
        expect(res2.ETag.length > 0).assertTrue()
      }
      const res3 = await client.completeMultipartUpload({
        Bucket: bucketName,
        Key: key,
        UploadID: res.UploadId,
        CompleteAll: true,
        Callback: hashCallback,
        CallbackVar: hashCallbackVar
      })
      expect(res3.CallbackResult?.includes('ok')).assertTrue();
      expect(res3.Bucket).assertEqual(bucketName);
      expect(res3.Key).assertEqual(key)
      expect(res3.ETag.length > 0).assertTrue();
      expect(res3.Location.length > 0).assertTrue();
    })
  })
}