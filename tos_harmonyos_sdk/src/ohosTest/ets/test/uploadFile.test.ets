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
  deleteBucket, genRandomId, getRandomLetter,
  getRandomNum,
  log, writeFile,
  writeFile2 } from './utils'
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { buffer } from '@kit.ArkTS';
import { UploadEventType } from '../../../../Index';

const context = abilityDelegatorRegistry.getAbilityDelegator().getAppContext();
export const filesDir = context.filesDir;


const client = new TosClient({
  accessKeyId:AK,
  accessKeySecret:SK,
  endpoint: Endpoint,
  region: Region
})
export default function uploadPartsTest(){

  describe('uploadFile', () => {
    beforeAll(async () => {
      // log('before all buketName: ' + bucketName)
      // await client.createBucket({
      //   Bucket: bucketName,
      // })
    })
    afterAll(async () => {
      // await deleteBucket(client, bucketName)
    })

    it('download_version', 0, async () => {
      const filePath = context.filesDir +  '/download_version/test'
      await client.downloadFile({
        Bucket: MultiVersionBucket,
        Key: 'sdk-test/file',
        FilePath: filePath,
        VersionID: '56D8CB92AE810496C31B'
      })

      const content = await fs.readText(filePath);
      expect(content).assertEqual('123');
    })

    it('download_dir', 0, async () => {
      const key = 'harmonyos-test/dir' + getRandomNum()
      const str = 'abc123';
      const res = await client.putObject({
        Bucket: TestBucket,
        Key: key,
        Content: buffer.from(str).buffer
      })

      const dirPath = context.filesDir + '/dir/'
      await client.downloadFile({
        Bucket: TestBucket,
        Key: key,
        FilePath: dirPath
      })

      const content1 = await fs.readText(dirPath + key);
      expect(content1).assertEqual(str);

      const dirPath2 = context.filesDir + '/dir2'
      await client.downloadFile({
        Bucket: TestBucket,
        Key: key,
        FilePath: dirPath2
      })
      const content2 = await fs.readText(dirPath2);
      expect(content2).assertEqual(str);

      const dirPath3 = context.filesDir + '/dir3';
      await fs.mkdir(dirPath3, true);
      await client.downloadFile({
        Bucket: TestBucket,
        Key: key,
        FilePath: dirPath3
      })
      const content3 = await fs.readText(dirPath3 + '/' + key);
      expect(content3).assertEqual(str);

      const ckPath = context.filesDir + '/test/ck.json';
      await client.downloadFile({
        Bucket: TestBucket,
        Key: key,
        FilePath: dirPath2,
        CheckpointFile: ckPath,
        EnableCheckpoint: true,
      })

      await assertError(async () => {
        await fs.stat(ckPath)
      }, {
        callback(e){
          expect(e.message).assertEqual('No such file or directory')
        }
      })

      const res2 = await client.uploadFile({
        Bucket: TestBucket,
        Key: key,
        FilePath: dirPath2,
        CheckpointFile: ckPath,
        EnableCheckpoint: true,
      })

      await assertError(async () => {
        await fs.stat(ckPath)
      }, {
        callback(e){
          expect(e.message).assertEqual('No such file or directory')
        }
      })
      expect(res.HashCrc64ecma).assertEqual(res2.HashCrc64ecma);
      expect(!!res.HashCrc64ecma?.length).assertEqual(true);

    })

    it('file_size_0', 0,async () => {
      const filePath = context.filesDir + '/a/b/zero.txt';
      const key = 'harmonyos-test2/aa' + getRandomNum()
      await client.putObject({
        Bucket: TestBucket,
        Key: key,
        Content: buffer.from('').buffer
      })

      await client.downloadFile({
        Bucket: TestBucket,
        Key: key,
        FilePath: filePath
      })

      const stat = await fs.stat(filePath);
      expect(stat.size).assertEqual(0)
      const key2 = 'harmonyos-test2/aa' + getRandomNum()
      await client.uploadFile({
        Bucket: TestBucket,
        Key: key2,
        FilePath: filePath
      })
      const res = await client.headObject({
        Bucket: TestBucket,
        Key: key2,
      })
      expect(res.ContentLength).assertEqual(0)
    })

    it('basic_usage', 0, async () => {
      const filePath = context.filesDir + '/a/b/test.txt';
      const res = await client.downloadFile({
        Bucket: TestBucket,
        Key: TEST_OBJECT_KEY,
        FilePath: filePath,
        DataTransferListener:{
          DataTransferStatusChange(status) {
            console.log('==>: ', status.ConsumedBytes)
          }
        }
      })

      const res2 = await client.uploadFile({
        Bucket: TestBucket,
        Key: 'new-test.txt',
        FilePath: filePath,
        DataTransferListener:{
          DataTransferStatusChange(status) {
            console.log('upload ==>: ', status.ConsumedBytes)
          }
        }
      })

      const res3 = await client.headObject({
        Bucket: TestBucket,
        Key: 'new-test.txt',
      })

      expect(res.HashCrc64ecma?.length && res.HashCrc64ecma.length > 0).assertTrue()
      expect(res.HashCrc64ecma).assertEqual(res2.HashCrc64ecma);
      expect(res2.HashCrc64ecma).assertEqual(res3.HashCrc64ecma);
      console.log('====> ', res.HashCrc64ecma)
    })

    it('task_num_part_size', 0, async () => {
      console.log('===> task_num_part_size')
      const filePath = context.filesDir + '/a/b/test2.txt';
      const res = await client.downloadFile({
        Bucket: TestBucket,
        Key: TEST_OBJECT_KEY,
        FilePath: filePath,
        TaskNum: 3,
        PartSize: 10 * 1024 * 1024
      })

      let count = 0;
      const res2 = await client.uploadFile({
        Bucket: TestBucket,
        Key: 'new-test2.txt',
        FilePath: filePath,
        TaskNum: 3,
        PartSize: 10 * 1024 * 1024,
        UploadEventListener: {
          EventChange(event){
            if (event.Type === UploadEventType.UploadPartSucceed) {
              count++;
            }
          }
        }
      })

      expect(count).assertEqual(10);

      const res3 = await client.headObject({
        Bucket: TestBucket,
        Key: 'new-test2.txt',
      })

      expect(res.HashCrc64ecma?.length && res.HashCrc64ecma.length > 0).assertTrue()
      expect(res.HashCrc64ecma).assertEqual(res2.HashCrc64ecma);
      expect(res2.HashCrc64ecma).assertEqual(res3.HashCrc64ecma);
      console.log('====> ', res.HashCrc64ecma)
    })
  })
}