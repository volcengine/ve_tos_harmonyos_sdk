/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TosClient } from '../../../main/ets/client'
import { AK, SK, AccountId, Region, Endpoint, InnerEndpoint, TestBucket } from '../../../../env'
import { genRandomId, log, specialCharKey } from './utils'
import { AzRedundancyType, StorageClassType, VersioningStatusType } from '../../../../Index';
import { encodeContentDisposition } from '../../../main/ets/utils/common'
import { buffer } from '@kit.ArkTS';

const client = new TosClient({
  accessKeyId: AK,
  accessKeySecret: SK,
  // securityToken: token,
  region: Region,
  endpoint: Endpoint,
});

export default function bucketTest() {
  describe('encode_test', () => {
    let bucketName = TestBucket//genRandomId();
    beforeAll(async  () => {
      log('before all')
      await client.createBucket({
        Bucket: bucketName,
      })
    })
    afterAll(() => {
      // Presets a clear action, which is performed after all test cases of the test suite end.
      // This API supports only one parameter: clear action function.
    })
    it('encode_content-disposition', 0, () => {
      const res1 = encodeContentDisposition("attachement; filename=\"中文.pdf\"")
      expect(res1).assertEqual('attachement; filename=' + '"' + encodeURIComponent("中文.pdf") + '"')

      const res6 = encodeContentDisposition("attachement; filename=\"？こんにちは안녕하세요.pdf\"")
      expect(res6).assertEqual('attachement; filename=' + '"' + encodeURIComponent("？こんにちは안녕하세요.pdf") + '"')

      const res2 = encodeContentDisposition("attachment; filename=\"filename.pdf\"");
      expect(res2).assertEqual("attachment; filename=\"filename.pdf\"")

      const res3 = encodeContentDisposition("attachement; filename*=\"中文.pdf\"")
      expect(res3).assertEqual("attachement; filename*=\"中文.pdf\"")

      const res4 = encodeContentDisposition('');
      expect(res4).assertEqual('');

      const res5 = encodeContentDisposition('abc');
      expect(res5).assertEqual('abc');
    })

    it('content-disposition', 0, async () => {
      const runCase = async (contentDisposition: string, index: number) => {
        await client.putObject({
          Bucket: bucketName,
          Key:'content-disposition/test' + index,
          Content: buffer.from('aa').buffer,
          ContentDisposition: contentDisposition
        })
        const res = await client.headObject({
          Bucket: bucketName,
          Key:'content-disposition/test' + index,

        })
        expect(res.ContentDisposition).assertEqual(contentDisposition)
      }

      const TESTChar = ["attachement; filename=\"中文.pdf\"", `attachement; filename="@#%@%！#（）？@#%%@%@#"`, "attachement; filename=\"abc1.pdf\"", "attachement; filename=\"？こんにちは안녕하세요.pdf\""]
      for (let i = 0; i < TESTChar.length; i++) {
        await runCase(TESTChar[i], i)
      }
    })

    it('meta_test', 0, async () => {
      const meta: Record<string, string> = {}
      meta['中文'] = '中文'
      meta['こんにちは안녕하세요'] = 'こんにちは안녕하세요'
      meta.special = specialCharKey;
      await client.putObject({
        Bucket: bucketName,
        Key:'x-tos-meta/test',
        Content: buffer.from('aa').buffer,
        Meta: meta
      })
      const res = await client.headObject({
        Bucket: bucketName,
        Key:'x-tos-meta/test',
      })
      expect(res.Meta?.special).assertEqual(specialCharKey)
      expect(res.Meta).assertDeepEquals(meta)
    })
  })
}