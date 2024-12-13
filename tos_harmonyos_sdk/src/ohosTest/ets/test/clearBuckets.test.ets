/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TosClient } from '../../../main/ets/client'
import { AK, SK, Endpoint, KMSMasterKeyID } from '../../../../env'
import { Bucket_Prefix, genRandomId, log } from './utils'
import { ObjectTobeDeleted } from '../../../main/ets/types/model2';
import { TosServerError } from '../../../../Index';
import { TosClientError } from '../../../../Index';

function handleError(error: Error) {
  if (error instanceof TosClientError) {
    log("TOS Client Err Msg:" + error.message);
    log("TOS Client Err Stack:"+ error.stack);
  } else if (error instanceof TosServerError) {
    log("TOS Request ID:"+  error.RequestID);
    log("TOS Response Status Code:"+ error.StatusCode);
    log("TOS Response Err Code:" + error.StatusCode);
    log("TOS Response Err Msg:" + error.Message);
  } else {
    log("TOS unexpected exception, message: " + error);
  }
}

const client = new TosClient({
  accessKeyId: AK,
  accessKeySecret: SK,
  // securityToken: token,
  region: Endpoint,
  endpoint: Endpoint,
});

export default function bucketMirrorBackTest() {
  describe('clear_bucket_test', () => {
    it('clear_bucket_test', 0, async () => {
      return;
      const res = await client.listBuckets();
      for (const bkt of res.Buckets) {
        try {
          if (bkt.Name.startsWith(Bucket_Prefix)) {
            log('begin to delete bucket: ' + bkt.Name)
            const res2 = await client.listObjectsType2({
              Bucket: bkt.Name
            });
            log('res2: ' + JSON.stringify(res2.Contents))
            try {
              if (res2.Contents.length > 0){
                const dmRes = await client.deleteMultiObjects({
                  Bucket: bkt.Name,
                  Objects: res2.Contents.map(item => new ObjectTobeDeleted(item.Key))
                })
                log('delete success: ' + JSON.stringify(dmRes))
              }
            } catch (e) {
              handleError(e)
            }
            await client.deleteBucket({
              Bucket: bkt.Name
            })
          }
        } catch (e) {
          handleError(e)
        }
      }
    })
  })
}