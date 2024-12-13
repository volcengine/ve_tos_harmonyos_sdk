/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TosClient } from '../../../main/ets/client'
import { AK, SK, Endpoint, KMSMasterKeyID, MultiVersionBucket } from '../../../../env'
import { assertError, deleteBucket, genRandomId, log, specialCharKey, waitForTime, writeFile } from './utils'
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { stringify } from '../../../main/ets/crypto';
import { buffer } from '@kit.ArkTS';
import axios, { AxiosResponse } from '@ohos/axios';
import { Any } from '../../../main/ets/types/common';
import { HeadObjectOutput, ListObjectsType2Output } from '../../../main/ets/types/model2';
import { http } from '@kit.NetworkKit';

interface Query extends Record<string, string> {
  prefix: string
}

const allTestObjectKeys = [
  '1',
  '2',
  '2/1',
  '2/2',
  '22/1',
  '22/2',
  '3',
  '3/',
  `${specialCharKey}`,
  `${specialCharKey}/1`,
  `${specialCharKey}/2`,
];

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

    for (const key of allTestObjectKeys) {
      await client.putObject({
        Bucket: bucketName,
        Key: key,
        Content: buffer.from(key).buffer,
      });
    }
  })
  afterAll(async () => {
    log('after all')
    await deleteBucket(client, bucketName);
  })

  describe('preSignedPolicyURLTest', () => {
    it('for_all_objects', 0, async () => {
      const res = await client.preSignedPolicyURL({
        Bucket: bucketName,
        Conditions: [
          {
            Key: 'key',
            Value: '',
            Operator: 'starts-with',
          },
        ],
      });
      const res2 =
        await axios.get<ListObjectsType2Output, AxiosResponse<ListObjectsType2Output, Any>>(res.GetSignedURLForList());
      for (let c of res2.data.Contents) {
        expect(c.Key).assertEqual(c.Key);
      }
      const res3 = await axios.get<string, AxiosResponse<string, Any>>(res.GetSignedURLForGetOrHead('22/2'));
      expect(res3.data).assertEqual('22/2')
    })

    it(
      'eq_one',
      0,
      async () => {
        const preSignedPolicyURLRet = await client.preSignedPolicyURL({
          Bucket: bucketName,
          Conditions: [
            {
              Key: 'key',
              Value: '1',
              Operator: 'eq',
            },
          ],
        });
        await assertError(async () => {
          await axios.get<ListObjectsType2Output, AxiosResponse<ListObjectsType2Output, Any>>(preSignedPolicyURLRet.GetSignedURLForList());
        })
        const query: Query = {
          prefix: '1'
        }
        await assertError(async () => {
          await axios.get<ListObjectsType2Output, AxiosResponse<ListObjectsType2Output, Any>>(preSignedPolicyURLRet.GetSignedURLForList(query));
        })
        const res =
          await axios.get<string, AxiosResponse<string, Any>>(preSignedPolicyURLRet.GetSignedURLForGetOrHead('1'));
        expect(String(res.data)).assertEqual('1')
      },
    );

    it('starts-with one', 0, async () => {
      const startOne = '2/';
      const preSignedPolicyURLRet = await client.preSignedPolicyURL({
        Bucket: bucketName,
        Conditions: [
          {
            Key: 'key',
            Value: startOne,
            Operator: 'starts-with',
          },
        ],
      });
      const query: Query = {
        prefix: startOne
      }
      const res = await axios.get<ListObjectsType2Output, AxiosResponse<ListObjectsType2Output, Any>>(
        preSignedPolicyURLRet.GetSignedURLForList(query)
      );
      expect(res.data.Contents.length).assertEqual(allTestObjectKeys.filter((it) => it.startsWith(startOne)).length)
      expect(res.data.Prefix).assertEqual(startOne);
      const res2 = await axios.head<HeadObjectOutput, AxiosResponse<HeadObjectOutput, Any>>(
        preSignedPolicyURLRet.GetSignedURLForGetOrHead('2/2')
      );
      expect(res2.headers['content-length']).assertEqual('3');
      await assertError(async () => {
        await axios.get<ListObjectsType2Output, AxiosResponse<ListObjectsType2Output, Any>>(preSignedPolicyURLRet.GetSignedURLForList())
      });
      const query2: Record<string, string> = {};
      query2.prefix = '22/'
      await assertError(async () => {
        await axios.get<ListObjectsType2Output, AxiosResponse<ListObjectsType2Output, Any>>(preSignedPolicyURLRet.GetSignedURLForList(query2))
      })
    })

    it('multi eq and starts-with', 0, async () => {
      const preSignedPolicyURLRet = await client.preSignedPolicyURL({
        Bucket: bucketName,
        Conditions: [
          {
            Key: 'key',
            Value: '1',
            Operator: 'eq',
          },
          {
            Key: 'key',
            Value: '2',
            Operator: 'eq',
          },
          {
            Key: 'key',
            Value: '2/',
            Operator: 'starts-with',
          },
          {
            Key: 'key',
            Value: '22/',
            Operator: 'starts-with',
          },
        ],
      });
      const query: Record<string, string> = {};
      query.prefix = '2/';
      const url = preSignedPolicyURLRet.GetSignedURLForList(query)
      const res2 =
        await axios.get<ListObjectsType2Output, AxiosResponse<ListObjectsType2Output, Any>>(url);
      log('res: ' + res2.data.Contents.length)
      expect(res2.data.Contents.length).assertEqual(allTestObjectKeys.filter(item => item.startsWith(query.prefix)).length);
      const testOneObj = async (key: string) => {
        const res = await axios.get<string, AxiosResponse<string, Object>>(
          preSignedPolicyURLRet.GetSignedURLForGetOrHead(key)
        );
        expect(String(res.data)).assertEqual(key);
      }
      await testOneObj('1');
      await testOneObj('2');
      await testOneObj('2/1');
      await testOneObj('22/1');
    })
  })
}