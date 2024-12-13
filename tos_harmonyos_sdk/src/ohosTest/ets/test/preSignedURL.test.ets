/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TosClient } from '../../../main/ets/client'
import { AK, SK, Endpoint, KMSMasterKeyID, MultiVersionBucket } from '../../../../env'
import { assertError, genRandomId, log, waitForTime, writeFile } from './utils'
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { stringify } from '../../../main/ets/crypto';
import { buffer } from '@kit.ArkTS';
import axios, { AxiosResponse } from '@ohos/axios';
import { Any } from '../../../main/ets/types/common';

const client = new TosClient({
  accessKeyId: AK,
  accessKeySecret: SK,
  // securityToken: token,
  region: Endpoint,
  endpoint: Endpoint,
});

export default function signedURLTest() {
  let bucketName = genRandomId('signed-url');
  beforeAll(async () => {
    log('before all buketName: ' + bucketName)
    await client.createBucket({
      Bucket: bucketName,
    })
  })
  afterAll(async () => {
    log('after all')
    await client.deleteObject({
      Bucket: bucketName,
      Key: 'test.txt',
    })
    await client.deleteObject({
      Bucket: bucketName,
      Key: 'test2.txt',
    })
    await client.deleteBucket({
      Bucket: bucketName,
    })
  })

  describe('signedURLTest', () => {
    it('pre_signed_url_test', 0, async () => {
      const ContentStr = 'content-str'
      await client.putObject({
        Bucket: bucketName,
        Key: 'test.txt',
        Content: buffer.from(ContentStr).buffer
      })

      const res = await client.preSignedURL({
        Bucket: bucketName,
        Key: 'test.txt',
      })
      const res2 = await axios.get<string, AxiosResponse<string, Any>>(res.SignedUrl);
      expect(res2.data).assertEqual(ContentStr)

      const putRes = await client.preSignedURL({
        Bucket: bucketName,
        Key: 'test2.txt',
        HttpMethod: 'PUT',
      })
      await axios.put<string, AxiosResponse<string, Any>>(putRes.SignedUrl, 'put-content');
      const res3 = await client.preSignedURL({
        Bucket: bucketName,
        Key: 'test2.txt',
        HttpMethod: 'GET',
      })
      const res4 = await axios.get<string, AxiosResponse<string, Any>>(res3.SignedUrl);
      expect(res4.data).assertEqual('put-content');
    })

    it('pre_signed_url_expires_test', 0, async () => {
      const res = await client.preSignedURL({
        Bucket: bucketName,
        Key: 'test.txt',
        Expires: 1,
      })

      await waitForTime(2000);
      await assertError(async () => {
        await axios.get<string, AxiosResponse<string, Any>>(res.SignedUrl);
      })
    })
  })
}