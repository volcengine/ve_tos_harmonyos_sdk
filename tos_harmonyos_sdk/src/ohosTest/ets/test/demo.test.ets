/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TosClient } from '../../../main/ets/client'
import { AK, SK, Endpoint, Region, KMSMasterKeyID, MultiVersionBucket, TestBucket, AccountId, TestCallBackUrl,
  TEST_OBJECT_KEY } from '../../../../env'
import { assertError, clearBucket,
  deepAssertStrList,
  deleteBucket, genRandomId, getRandomLetter, log, writeFile,
  writeFile2 } from './utils'
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { buffer } from '@kit.ArkTS';

const context = abilityDelegatorRegistry.getAbilityDelegator().getAppContext();
export const filesDir = context.filesDir;


const client = new TosClient({
  accessKeyId:AK,
  accessKeySecret:SK,
  endpoint: Endpoint,
  region: Region
})
export default function uploadPartsTest(){
  let bucketName = TestBucket//genRandomId('parts');

  describe('demo', () => {
    beforeAll(async () => {
      // log('before all buketName: ' + bucketName)
      // await client.createBucket({
      //   Bucket: bucketName,
      // })
    })
    afterAll(async () => {
      // await deleteBucket(client, bucketName)
    })

    it('basic_usage', 0, async () => {
      const filePath = context.filesDir + '/a/b/';
      try {
        const res = await client.downloadFile({
          Bucket: TestBucket,
          Key: TEST_OBJECT_KEY,
          FilePath: filePath,
          DataTransferListener: {
            DataTransferStatusChange(status){
              console.log('type status ===>: ', status.Type)
              console.log('ConsumedBytes status ===>: ', status.ConsumedBytes)
              console.log('RWOnceBytes status ===>: ', status.RWOnceBytes)
              console.log('TotalBytes status ===>: ', status.TotalBytes)
            }
          }
        })
      } catch (e) {
        const err2 = e as Error;
      }
    })
  })
}