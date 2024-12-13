/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium';
import { TosClient } from '../../../main/ets/client'
import { AK, SK, Region, Endpoint } from '../../../../env'
import { deleteBucket, genRandomId, log } from './utils'
import { buffer } from '@kit.ArkTS';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { fileIo as fs, ReadOptions } from '@kit.CoreFileKit';

let abilityDelegator: abilityDelegatorRegistry.AbilityDelegator;

abilityDelegator = abilityDelegatorRegistry.getAbilityDelegator();

let context = abilityDelegator.getAppContext();

const client = new TosClient({
  accessKeyId: AK,
  accessKeySecret: SK,
  // securityToken: token,
  region: Region,
  endpoint: Endpoint,
});

export default function bucketTest() {
  describe('stream_test', () => {
    let bucketName = genRandomId();
    beforeAll(async () => {
      log('before all')
      await client.createBucket({
        Bucket: bucketName,
      })
    })

    afterAll(async () => {
      log('after all')
      await deleteBucket(client, bucketName);
    })
    it('basic_stream', 0, async  () => {
      const content = 'abcdefghjjl你好123#%#……#¥……¥#634？？字符12111asjdaklllllaa'
      const res = await client.putObject({
        Bucket: bucketName,
        Key:'stream-test/origin-object',
        Content: buffer.from(content).buffer
      })

      const filePath = context.filesDir + 'test.txt'
      const file = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      fs.writeSync(file.fd, content);
      const res3 = await client.putObjectFromFile({
        Bucket: bucketName,
        Key:'stream-test/new-object',
        FilePath: filePath
      })
      expect(res.HashCrc64ecma).assertEqual(res3.HashCrc64ecma);
    })
  })
}