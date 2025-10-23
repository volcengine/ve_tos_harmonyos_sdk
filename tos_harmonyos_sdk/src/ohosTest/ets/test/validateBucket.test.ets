/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TosClient } from '../../../main/ets/client'
import { AK, SK, Endpoint, KMSMasterKeyID } from '../../../../env'
import { assertError, genRandomId, log } from './utils'
import { TosClientError } from '../../../main/ets/TosClientError';

const client = new TosClient({
  accessKeyId: AK,
  accessKeySecret: SK,
  // securityToken: token,
  region: Endpoint,
  endpoint: Endpoint,
});

export default function validateBucketNameTest(){
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

  describe('validate_bucket_name_test', () => {
    it('validate_bucket_name_test', 0, async () => {
      await assertError(async () => {
        await client.headBucket({
          Bucket:'ab'
        })
      }, {
        message:'invalid bucket name, the length must be [3, 63]'
      })

      await assertError(async () => {
        await client.createBucket({
          Bucket:'a'.repeat(64)
        })
      }, {
        message:'invalid bucket name, the length must be [3, 63]'
      })

      await assertError(async () => {
        await client.putObject({
          Bucket:'aa@@aa',
          Key: 'abc'
        })
      }, {
        message:'invalid bucket name, the character set is illegal'
      })

      await assertError(async () => {
        await client.getBucketLocation({
          Bucket:'aaaa--',
        })
      }, {
        message:'invalid bucket name, the bucket name can be neither starting with \'-\' nor ending with \'-\''
      })
    })
  })

}