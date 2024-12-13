/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TosClient } from '../../../main/ets/client'
import { AK, SK, Endpoint, KMSMasterKeyID, MultiVersionBucket, TestBucket } from '../../../../env'
import { assertError, clearBucket,
  deepAssertStrList,
  deleteBucket, genRandomId, getRandomLetter, log, writeFile } from './utils'
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { hashMd5, hashMd5ToStr, stringify } from '../../../main/ets/crypto';
import { buffer } from '@kit.ArkTS';
import { StorageClassType, TosServerError } from '../../../../Index';
import { ListedUpload } from '../../../main/ets/types/model2';


const client = new TosClient({
  accessKeyId: AK,
  accessKeySecret: SK,
  // securityToken: token,
  region: Endpoint,
  endpoint: Endpoint,
});
export default function partsTest(){
  let bucketName = genRandomId('parts');
  describe('parts_test', () => {
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
      const res = await client.createMultipartUpload({
        Bucket: bucketName,
        Key: 'parts_basic_usage'
      })
      expect(res.Bucket).assertEqual(bucketName)
      expect(res.Key).assertEqual('parts_basic_usage');
      const res2 = await client.listMultipartUploads({
        Bucket: bucketName,
      })
      //expect(res2.Uploads.some(upload => upload.Key === ))
      const upload = res2.Uploads.find(upload => upload.UploadId === res.UploadId);
      expect(upload!.Key).assertEqual(res.Key);
      const res3 = await client.abortMultipartUpload({
        Bucket: bucketName,
        Key: 'parts_basic_usage',
        UploadID: res.UploadId
      })
      expect(res3.StatusCode).assertLess(300);
      const res4 = await client.listMultipartUploads({
        Bucket: bucketName,
      })
      expect(!!res4.Uploads.find(upload => upload.UploadId === res.UploadId)).assertFalse();
    })
    it('createMultipartUpload_test', 0 , async () => {
      const ssecKey = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const ssecKeyMd5 = hashMd5ToStr(ssecKey, 'base64');
      const res = await client.createMultipartUpload({
        Bucket: bucketName,
        Key: 'createMultipartUpload_test',
        EncodingType: 'url',
        StorageClass: StorageClassType.StorageClassArchiveFr,
        SSECAlgorithm: 'AES256',
        SSECKey: stringify(new Uint8Array(buffer.from(ssecKey).buffer), 'base64'),
        SSECKeyMD5: ssecKeyMd5,
      })
      // expect(res.EncodingType).assertEqual('url');
      expect(res.SSECAlgorithm).assertEqual('AES256');
      expect(res.SSECKeyMD5).assertEqual(ssecKeyMd5);
      const res2 = await client.listMultipartUploads({
        Bucket: bucketName,
      })
      const upload = res2.Uploads.find(item => item.UploadId === res.UploadId);
      expect(upload?.StorageClass).assertEqual(StorageClassType.StorageClassArchiveFr);
      await client.abortMultipartUpload({
        Bucket: bucketName,
        Key: 'createMultipartUpload_test',
        UploadID: res.UploadId
      })
    })
    it('list_MultipartUpload_test', 0, async () => {
      const res = await client.listMultipartUploads({
        Bucket: bucketName,
        Prefix: '他est/',
        Delimiter: '你',
        MaxUploads: 10,
      })
      expect(res.Bucket).assertEqual(bucketName);
      expect(res.Prefix).assertEqual('他est/');
      expect(res.Delimiter).assertEqual('你');
      expect(res.MaxUploads).assertEqual(10);

      const res2 = await client.listMultipartUploads({
        Bucket: bucketName,
        MaxUploads: 10,
        EncodingType: 'url'
      })
      expect(res2.Bucket).assertEqual(bucketName);
      expect(res2.EncodingType).assertEqual('url');
    })
    it('list_MultipartUpload_next_page', 0, async () => {
      const Count = 15;
      const Keys: string[] = new Array(Count).fill(0).map((_: string, index) => {
        return 'multi_part_upload/' + `${index}`.padStart(2, '0')
      })
      for (const k of Keys) {
        await client.createMultipartUpload({
          Bucket: bucketName,
          Key: k,
        })
      }
      let uploadList: ListedUpload[] = [];
      let keyMarker = '';
      let uploadIdMarker = '';
      let i = 0;
      while (true) {
        const res = await client.listMultipartUploads({
          Bucket: bucketName,
          KeyMarker: keyMarker,
          UploadIdMarker: uploadIdMarker,
          MaxUploads: 10,
        })
        expect(res.KeyMarker).assertEqual(keyMarker);
        expect(res.UploadIdMarker).assertEqual(uploadIdMarker);
        if (i === 0) {
          expect(res.IsTruncated).assertEqual(true);
        } else if(i === 1){
          expect(res.IsTruncated).assertEqual(false);
        }
        uploadList = uploadList.concat(res.Uploads);
        if (res.NextKeyMarker && res.NextUploadIdMarker) {
          keyMarker = res.NextKeyMarker;
          uploadIdMarker = res.NextUploadIdMarker;
        } else {
          break;
        }
        i++;
      }
      deepAssertStrList(uploadList.map(item => item.Key), Keys);
      const res2 = await client.listMultipartUploads({
        Bucket: bucketName,
        Delimiter: '/'
      })
      expect(res2.CommonPrefixes[0].Prefix).assertEqual('multi_part_upload/')
    })
    it('parts_ssec', 0, async () => {
      const key = 'test-upload-parts-ssec';
      const chunkSize = 4 * 1024 * 1024;
      const count = 2;
      const ssecKey = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const ssecMd5 = hashMd5ToStr(ssecKey, 'base64');
      const res = await client.createMultipartUpload({
        Bucket: bucketName,
        Key: key,
        SSECAlgorithm: 'AES256',
        SSECKey: stringify(new Uint8Array(buffer.from(ssecKey).buffer), 'base64'),
        SSECKeyMD5: ssecMd5,
      })
      log('create MultipartUpload success')
      for (let i = 1; i < count + 1; i++) {
        const chunk = buffer.from(getRandomLetter(i).repeat(chunkSize)).buffer
        const res2 = await client.uploadPart({
          Bucket: bucketName,
          Key: key,
          UploadID: res.UploadId,
          PartNumber: i,
          Content: chunk,
          SSECAlgorithm: 'AES256',
          SSECKey: stringify(new Uint8Array(buffer.from(ssecKey).buffer), 'base64'),
          SSECKeyMD5: ssecMd5,
        })
        expect(res2.PartNumber).assertEqual(i);
        expect(res2.ETag.length > 0).assertTrue();
        expect(res2.HashCrc64ecma && res2.HashCrc64ecma.length > 0).assertTrue();
      }
      const completeMultipartUploadRes = await client.completeMultipartUpload({
        Bucket: bucketName,
        Key: key,
        UploadID: res.UploadId,
        CompleteAll: true,
      })
      expect(completeMultipartUploadRes.HashCrc64ecma && completeMultipartUploadRes.HashCrc64ecma.length > 0).assertTrue();
      const res2 = await client.headObject({
        Bucket: bucketName,
        Key: key,
        SSECAlgorithm: 'AES256',
        SSECKey: stringify(new Uint8Array(buffer.from(ssecKey).buffer), 'base64'),
        SSECKeyMD5: ssecMd5,
      })
      expect(res2.ContentLength).assertEqual(count * chunkSize);
      await assertError(async () => {
        await client.headObject({
          Bucket: bucketName,
          Key: key,
          SSECAlgorithm: 'AES256',
          SSECKey: stringify(new Uint8Array(buffer.from(ssecKey).buffer), 'base64'),
          SSECKeyMD5: '111',
        })
      })
    })
  })
}