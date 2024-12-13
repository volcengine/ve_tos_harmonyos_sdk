/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TosClient } from '../../../main/ets/client'
import { AK, SK, Endpoint, KMSMasterKeyID } from '../../../../env'
import { assertError, genRandomId, log } from './utils'
import { GetBucketEncryptionOutput, GetBucketMirrorBackOutput, MirrorBackRule, RedirectType } from '../../../../Index';

const client = new TosClient({
  accessKeyId: AK,
  accessKeySecret: SK,
  // securityToken: token,
  region: Endpoint,
  endpoint: Endpoint,
});

export default function bucketMirrorBackTest() {
  let bucketName = genRandomId();
  beforeAll(async () => {
    log('before all')
    await client.createBucket({
      Bucket: bucketName,
    })
    log('bucket created: ' + bucketName)
  })

  afterAll(async () => {
    log('after all')
    // await client.deleteBucket({
    //   Bucket: bucketName,
    // })
  })

  describe('bucket_mirror_test', () => {
    it('bucket_mirror_test', 0, async () => {
      const Rules: MirrorBackRule[] = [
        {
          ID: 'test1',
          Condition: {
            HttpCode: 404,
            KeyPrefix: "prefix-",
            KeySuffix: "-suffix",
          },
          Redirect: {
            RedirectType: RedirectType.RedirectTypeMirror,
            FetchSourceOnRedirect: true,
            PassQuery: true,
            FollowRedirect: true,
            MirrorHeader: {
              PassAll: true,
              Pass: ['aa', 'bb'],
              Remove: ['xx']
            },
            Transform: {
              WithKeyPrefix: "prefix-",
              WithKeySuffix: "-suffix",
              ReplaceKeyPrefix: {
                KeyPrefix: "prefix-",
                ReplaceWith: "replace-",
              },
            },
            PublicSource: {
              SourceEndpoint: {
                Primary: ["http://www.volcengine.com/obj/tostest/"],
                Follower: ["http://www.volcengine.com/obj/tostest/"],
              },
            },
            // FetchHeaderToMetaDataRule: {
            //   SourceHeader:   "x-source-header",
            //   MetaDataSuffix: "meta-data-suffix",
            // }
          }
        },
        {
          ID: 'test21',
          Condition: {
            HttpCode: 404,
            KeyPrefix: 'object-key-prefix',
            KeySuffix: 'object-key-suffix',
          },
          Redirect: {
            RedirectType: RedirectType.RedirectTypeAsync,
            FetchSourceOnRedirect: false,
            PublicSource: {
              SourceEndpoint: {
                Primary: ['http://abc.123/'],
              },
            },
            PassQuery: true,
            FollowRedirect: true,
            MirrorHeader: {
              PassAll: true,
              Pass: ['aaa', 'bbb'],
              Remove: ['xxx', 'yyy'],
            },
            Transform: {
              WithKeyPrefix: 'addtional-key-prefix',
              WithKeySuffix: 'addtional-key-suffix',
              ReplaceKeyPrefix: {
                KeyPrefix: 'key-prefix',
                ReplaceWith: 'replace-with',
              },
            },
          },
        }
      ]
      const res = await client.putBucketMirrorBack({
        Bucket: bucketName,
        Rules,
      })
      expect(res.StatusCode).assertLess(300)

      let res2: GetBucketMirrorBackOutput;
      res2 = await client.getBucketMirrorBack({
        Bucket: bucketName
      })
      expect(res2.StatusCode).assertLess(300);
      expect(res2.Rules[0]).assertDeepEquals(Rules[0]);
      res2.Rules[1].Redirect.FetchSourceOnRedirect = false;
      expect(res2.Rules).assertDeepEquals(Rules);
      await client.deleteBucketMirrorBack({
        Bucket: bucketName,
      })
      await assertError(async () => {
        await client.getBucketMirrorBack({
          Bucket: bucketName
        })
      }, {
        statusCode: 404,
        code: 'NoSuchMirrorConfiguration'
      })
    })
  })
}