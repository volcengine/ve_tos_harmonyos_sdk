/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TosClient } from '../../../main/ets/client'
import { AK, SK, Endpoint, KMSMasterKeyID, MultiVersionBucket, TestBucket } from '../../../../env'
import { assertError, clearBucket,
  deepAssertStrList,
  deleteBucket, genRandomId, getRandomLetter,
  getRandomNum,
  log, writeFile } from './utils'
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { hashMd5, hashMd5ToStr, stringify } from '../../../main/ets/crypto';
import { buffer } from '@kit.ArkTS';
import { StorageClassType, TosServerError } from '../../../../Index';
import { ListedUpload } from '../../../main/ets/types/model2';
import axios, { AxiosResponse } from '@ohos/axios';
import { Any } from '../../../main/ets/types/common';


const client = new TosClient({
  accessKeyId: AK,
  accessKeySecret: SK,
  // securityToken: token,
  region: Endpoint,
  endpoint: Endpoint,
});
export default function uploadPartCopyTest(){
  let bucketName = genRandomId('parts');
  describe('uploadPartCopyTest', () => {
    beforeAll(async () => {
      log('before all buketName: ' + bucketName)
      await client.createBucket({
        Bucket: bucketName,
      })
    })
    afterAll(async () => {
      await deleteBucket(client, bucketName)
    })
    it('upload_part_copy', 0, async () => {
      const key = 'test-upload_part_copy';
      const res = await client.createMultipartUpload({
        Bucket: bucketName,
        Key: key,
      })

      const srcBucketName = genRandomId('src-bucket');
      const srcKey = 'src-key'
      const contentStr = 'a'.repeat(1024 * 1024 * 4)
      await client.createBucket({
        Bucket: srcBucketName
      })
      await client.putObject({
        Bucket: srcBucketName,
        Key: srcKey,
        Content: buffer.from(contentStr).buffer
      })

      const res2 = await client.uploadPartCopy({
        Bucket: bucketName,
        Key: key,
        UploadID: res.UploadId,
        PartNumber: 1,
        SrcBucket: srcBucketName,
        SrcKey: srcKey
      })

      expect(res2.ETag.length > 0).assertTrue();

      await client.completeMultipartUpload({
        Bucket: bucketName,
        Key: key,
        UploadID: res.UploadId,
        CompleteAll: true,
      })
      log('completeMultipartUpload success')
      const res3 = await client.preSignedURL({
          Bucket: bucketName,
          Key: key,
          HttpMethod: 'GET',
      })
      const contentStr2 = await axios.get<string, AxiosResponse<string, Any>>(res3.SignedUrl);

      log('getObject success')
      expect(contentStr2.data).assertEqual(contentStr)
    })

    it('upload_part_copy_mul_version', 0, async () => {
      const keyPrefix = 'mul_version' +  getRandomNum() + '/'
      const key = keyPrefix + 'test';
      const res = await client.createMultipartUpload({
        Bucket: MultiVersionBucket,
        Key: key,
      })
      const prefix = 'sdk-test' + getRandomNum() + '/';
      const srcKey = prefix + 'src-key';
      const contentStr = 'a'.repeat(1024 * 1024 * 4)
      await client.createBucket({
        Bucket: MultiVersionBucket
      })
      await client.putObject({
        Bucket: MultiVersionBucket,
        Key: srcKey,
        Content: buffer.from(contentStr).buffer
      })

      await client.deleteObject({
        Bucket: MultiVersionBucket,
        Key: srcKey,
      })

      const res2 = await client.listObjectVersions({
        Bucket: MultiVersionBucket,
        Prefix: prefix
      })

      expect(res2.Versions.length).assertEqual(1);
      expect(res2.DeleteMarkers.length).assertEqual(1);

      const res3 = await client.uploadPartCopy({
        Bucket: MultiVersionBucket,
        Key: key,
        UploadID: res.UploadId,
        PartNumber: 1,
        SrcBucket: MultiVersionBucket,
        SrcKey: srcKey,
        SrcVersionID: res2.Versions[0].VersionId
      })
      expect(res3.ETag.length > 0).assertTrue();

      await client.completeMultipartUpload({
        Bucket: MultiVersionBucket,
        Key: key,
        UploadID: res.UploadId,
        CompleteAll: true,
      })
      log('completeMultipartUpload success')
      const res5 = await client.listObjectVersions({
        Bucket: MultiVersionBucket,
        Prefix: keyPrefix
      })

      const query: Record<string, string> = {};
      query.versionId = res5.Versions[0].VersionId
      const res4 = await client.preSignedURL({
        Bucket: MultiVersionBucket,
        Key: key,
        HttpMethod: 'GET',
        Query: query
      })
      const contentStr2 = await axios.get<string, AxiosResponse<string, Any>>(res4.SignedUrl);
      expect(contentStr).assertEqual(contentStr2.data)
    })

    it('upload_part_copy_custom_header', 0, async () => {
      const key = 'test-upload_part_copy_custom';
      const res = await client.createMultipartUpload({
        Bucket: bucketName,
        Key: key,
      })

      const srcBucketName = genRandomId('src-bucket');
      const srcKey = 'src-key'
      const contentStr = 'a'.repeat(1024 * 1024 * 4)
      await client.createBucket({
        Bucket: srcBucketName
      })
      await client.putObject({
        Bucket: srcBucketName,
        Key: srcKey,
        Content: buffer.from(contentStr).buffer
      })

      const res2 = await client.headObject({
        Bucket: srcBucketName,
        Key: srcKey,
      })

      await assertError(async () => {
        await client.uploadPartCopy({
          Bucket: bucketName,
          Key: key,
          UploadID: res.UploadId,
          PartNumber: 1,
          SrcBucket: srcBucketName,
          SrcKey: srcKey,
          RequestHeader: {
            'x-tos-copy-source-if-match': 'abc'
          }
        })
      }, {
        callback(err){
          const err2 = err as TosServerError;
          expect(err2.Code).assertEqual('PreconditionFailed')
        }
      })

      const res3 = await client.uploadPartCopy({
        Bucket: bucketName,
        Key: key,
        UploadID: res.UploadId,
        PartNumber: 1,
        SrcBucket: srcBucketName,
        SrcKey: srcKey,
        RequestHeader: {
          'x-tos-copy-source-if-match': res2.ETag
        }
      })
      expect(res3.ETag.length > 0).assertTrue();
    })
  })
}