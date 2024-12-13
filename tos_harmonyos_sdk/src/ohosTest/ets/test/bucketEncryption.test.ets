/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TosClient } from '../../../main/ets/client'
import { AK, SK, Endpoint, KMSMasterKeyID } from '../../../../env'
import { assertError, genRandomId, log } from './utils'
import {  GetBucketEncryptionOutput } from '../../../../Index';

const client = new TosClient({
  accessKeyId: AK,
  accessKeySecret: SK,
  // securityToken: token,
  region: Endpoint,
  endpoint: Endpoint,
});

export default function bucketEncryptionTest() {
  let bucketName = genRandomId();
  beforeAll(async () => {
    log('before all')
    await client.createBucket({
      Bucket: bucketName,
    })
  })

  afterAll(async () => {
    log('after all')
    await client.deleteBucket({
      Bucket: bucketName,
    })
  })

  describe('bucket_encryption_test', () => {
    it('bucket_encryption_test', 0, async () => {
      await client.putBucketEncryption({
        Bucket: bucketName,
        Rule: {
          ApplyServerSideEncryptionByDefault: {
            SSEAlgorithm: 'AES256'
          }
        }
      })

      const res = await client.getBucketEncryption({
        Bucket: bucketName,
      })
      expect(res.Rule.ApplyServerSideEncryptionByDefault.SSEAlgorithm).assertDeepEquals('AES256')
      await client.putBucketEncryption({
        Bucket: bucketName,
        Rule: {
          ApplyServerSideEncryptionByDefault: {
            SSEAlgorithm: 'kms',
            KMSMasterKeyID,
          }
        }
      })

      const res2 = await client.getBucketEncryption({
        Bucket: bucketName,
      })

      expect(res2.Rule.ApplyServerSideEncryptionByDefault.SSEAlgorithm).assertEqual('kms');
      expect(res2.Rule.ApplyServerSideEncryptionByDefault.KMSMasterKeyID).assertEqual(KMSMasterKeyID)

      const res3 = await client.deleteBucketEncryption({
        Bucket: bucketName,
      })
      log(`delete bucket encryption status code: ${res3.StatusCode}`);
      expect(res3.StatusCode).assertLess(300);
      await assertError(async () => {
        await client.getBucketEncryption({
          Bucket: bucketName
        })
      }, {
        statusCode: 404,
        code: 'NoSuchBucketEncryption'
      })
    })
  })
}