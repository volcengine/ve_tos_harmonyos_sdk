/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium';
import { TosClient } from '../../../main/ets/client'
import { AK, SK, Endpoint} from '../../../../env'
import { deleteBucket, genRandomId, log,  } from './utils'
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
export default function parts2Test(){
  let bucketName = genRandomId('parts');
  describe('parts_2_test', () => {
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
      const key = 'parts_basic_usage'
      const res = await client.createMultipartUpload({
        Bucket: bucketName,
        Key: key
      })
      expect(res.Bucket).assertEqual(bucketName)
      expect(res.Key).assertEqual('parts_basic_usage');
      const str1 = 'a'.repeat(1024 * 1024) + 'b'.repeat(1024*1024) + 'c'.repeat(1024 * 1024) + 'd'.repeat(1024 * 1024)
      const str2 = 'e'.repeat(1024 * 1024) + 'f'.repeat(1024*1024) + 'g'.repeat(1024 * 1024) + 'f'.repeat(1024 * 1024)
      const str3 = '1'.repeat(1024 * 1024) + '2'.repeat(1024*1024) + '3'.repeat(1024 * 1024) + '4'.repeat(1024 * 1024)
      const buf = buffer.from(str1);
      const buf2 = buffer.from(str2);
      const buf3 = buffer.from(str3);
      await client.uploadPart({
        Bucket: bucketName,
        Key: key,
        PartNumber: 1,
        UploadID: res.UploadId,
        Content: buf.buffer//fs.createReadStream(path)
      })
      await client.uploadPart({
        Bucket: bucketName,
        Key: key,
        PartNumber: 2,
        UploadID: res.UploadId,
        Content: buf2.buffer//fs.createReadStream(path)
      })
      await client.uploadPart({
        Bucket: bucketName,
        Key: key,
        PartNumber: 3,
        UploadID: res.UploadId,
        Content: buf3.buffer//fs.createReadStream(path)
      })
      await client.completeMultipartUpload({
        Bucket: bucketName,
        Key: key,
        UploadID: res.UploadId,
        CompleteAll: true,
      })
      const res2 = await client.preSignedURL({
        Bucket: bucketName,
        Key: key,
      })
      const res3 = await axios.get<string, AxiosResponse<string, Any>>(res2.SignedUrl);
      expect(res3.data).assertEqual(str1 + str2 + str3);
    })
  })
}