/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TosClient } from '../../../main/ets/client'
import { AK, SK, AccountId, Region, Endpoint, InnerEndpoint } from '../../../../env'
import { deleteBucket, genRandomId, log } from './utils'
import { AzRedundancyType, HeadObjectOutput, StorageClassType, VersioningStatusType } from '../../../../Index';
import axios, { AxiosResponse } from '@ohos/axios';
import { Any } from '../../../main/ets/types/common';

export default function bucketTest() {
  describe('http_scheme_test', () => {
    it('empty_endpoint', 0 ,async () => {
      const client = new TosClient({
        accessKeyId: AK,
        accessKeySecret: SK,
        // securityToken: token,
        region: Region,
      });
      const TEST_BUCKET = genRandomId('http-schema');
      await client.createBucket({
        Bucket: TEST_BUCKET,
      })
      await client.putObject({
        Bucket: TEST_BUCKET,
        Key:'test-empty_endpoint'
      })
      await deleteBucket(client, TEST_BUCKET)
    })
    it('http_scheme_test', 0, async  () => {
      const client = new TosClient({
        accessKeyId: AK,
        accessKeySecret: SK,
        // securityToken: token,
        region: Region,
        endpoint: 'http://' + Endpoint,
      });
      const TEST_BUCKET = genRandomId('http-schema');
      await client.createBucket({
        Bucket: TEST_BUCKET,
      })

      await client.putObject({
        Bucket: TEST_BUCKET,
        Key:'test-scheme_http'
      })
      const res3 = await client.headObject({
        Bucket: TEST_BUCKET,
        Key:'test-scheme_http'
      })
      expect(res3.ETag.length > 0).assertTrue();
      const putRes = await client.preSignedURL({
        Bucket: TEST_BUCKET,
        Key: 'test-scheme_http_pre_signed',
        HttpMethod: 'PUT',
      })
      expect(putRes.SignedUrl.startsWith('http://')).assertTrue();
      await axios.put<string, AxiosResponse<string, Any>>(putRes.SignedUrl, 'put-content');
      const policyRes = await client.preSignedPolicyURL({
        Bucket: TEST_BUCKET,
        Conditions: [{
          Key: 'key',
          Value: 'te',
          Operator:'starts-with',
        }]
      })

      const getUrl = policyRes.GetSignedURLForGetOrHead('test-scheme_http_pre_signed')
      expect(getUrl.startsWith('http')).assertTrue();
      const res2 = await axios.get<string, AxiosResponse<string, Any>>(
        getUrl
      );
      expect(res2.data).assertEqual('put-content')
      await deleteBucket(client, TEST_BUCKET)
    })
    it('https_scheme_test', 0, async  () => {
      const client = new TosClient({
        accessKeyId: AK,
        accessKeySecret: SK,
        // securityToken: token,
        region: Region,
        endpoint: 'https://' + Endpoint,
      });
      const TEST_BUCKET = genRandomId('http-schema');
      await client.createBucket({
        Bucket: TEST_BUCKET,
      })

      await client.putObject({
        Bucket: TEST_BUCKET,
        Key:'test-scheme_http'
      })

      const res3 = await client.headObject({
        Bucket: TEST_BUCKET,
        Key:'test-scheme_http'
      })
      expect(res3.ETag.length > 0).assertTrue();
      const putRes = await client.preSignedURL({
        Bucket: TEST_BUCKET,
        Key: 'test-scheme_http_pre_signed',
        HttpMethod: 'PUT',
      })
      expect(putRes.SignedUrl.startsWith('https://')).assertTrue();
      await axios.put<string, AxiosResponse<string, Any>>(putRes.SignedUrl, 'put-content');
      const policyRes = await client.preSignedPolicyURL({
        Bucket: TEST_BUCKET,
        Conditions: [{
          Key: 'key',
          Value: 'te',
          Operator:'starts-with',
        }]
      })

      const getUrl = policyRes.GetSignedURLForGetOrHead('test-scheme_http_pre_signed')
      expect(getUrl.startsWith('https://')).assertTrue();
      const res2 = await axios.get<string, AxiosResponse<string, Any>>(
        getUrl
      );
      expect(res2.data).assertEqual('put-content')
      await deleteBucket(client, TEST_BUCKET)
    })
  })
}