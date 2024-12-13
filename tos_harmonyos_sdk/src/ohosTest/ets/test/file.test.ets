/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TosClient } from '../../../main/ets/client'
import { AK, SK, Endpoint, KMSMasterKeyID, MultiVersionBucket, TestBucket } from '../../../../env'
import { assertError, clearBucket, deleteBucket, genRandomId, getRandomLetter, log, writeFile } from './utils'
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { hashMd5, hashMd5ToStr, stringify } from '../../../main/ets/crypto';
import { buffer } from '@kit.ArkTS';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { fileIo as fs, ReadOptions } from '@kit.CoreFileKit';

const context = abilityDelegatorRegistry.getAbilityDelegator().getAppContext();
export const filesDir = context.filesDir;

const client = new TosClient({
  accessKeyId: AK,
  accessKeySecret: SK,
  // securityToken: token,
  region: Endpoint,
  endpoint: Endpoint,
});

const writeFileFromBuf = async (path: string, buf: ArrayBuffer) => {
  let file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
  // 写入一段内容至文件
  let writeLen = fs.writeSync(file.fd, buf);
}

export default function fileTest(){
  let bucketName = genRandomId('large-file');

  describe('file_test', () => {
    beforeAll(async () => {
      log('before all buketName: ' + bucketName)
      await client.createBucket({
        Bucket: bucketName,
      })
    })
    afterEach(async () => {
      await deleteBucket(client, bucketName)
    })

    it('put_object_from_file', 0, async () => {
      const totalSize = 1024 * 34
      const buf = buffer.alloc(totalSize);
      const singeSize = 1024
      let written = 0;
      let i = 0;
      while (written < totalSize) {
        buf.write(getRandomLetter(i).repeat(singeSize), written)
        written += singeSize;
        i++;
      }
      writeFileFromBuf(filesDir + 'file', buf.buffer);
      const md5 = hashMd5ToStr(new Uint8Array(buf.buffer), 'base64')
      await client.putObjectFromFile({
        Bucket: bucketName,
        Key: 'test-upload-from-file',
        FilePath: filesDir + 'file',
        ContentMD5: md5
      });
      const res = await client.headObject({
        Bucket: bucketName,
        Key: 'test-upload-from-file',
      });
      expect(res.ContentLength).assertEqual(totalSize);
    })
  })
}