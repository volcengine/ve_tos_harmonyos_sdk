/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TosClient } from '../../../main/ets/client'
import { CancelHook } from '../../../main/ets/cancel'
import { AK, SK, Endpoint, Region, TestBucket, TEST_OBJECT_KEY } from '../../../../env'
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

  describe('uploadFile2', () => {
    beforeAll(async () => {
      // log('before all buketName: ' + bucketName)
      // await client.createBucket({
      //   Bucket: bucketName,
      // })
    })
    afterAll(async () => {
      // await deleteBucket(client, bucketName)
    })

    it('cancel_and_checkpoint', 0, async () => {
      const filePath = context.filesDir + '/a/b/test.txt';
      const checkpointPath = context.filesDir + '/c/d/cp.json';
      const cancelHook = new CancelHook();
      const res = await client.headObject({
        Bucket: TestBucket,
        Key: TEST_OBJECT_KEY,
      })

      let size1 = 0;
      let size2 = 0;
      try {
        const res2 = await client.downloadFile({
          Bucket: TestBucket,
          Key: TEST_OBJECT_KEY,
          FilePath: filePath,
          CancelHook: cancelHook,
          CheckpointFile: checkpointPath,
          DataTransferListener: {
            DataTransferStatusChange(status){
              size1 += status.RWOnceBytes;
              console.log('size1 ===> ', size1)
              if (size1 > 40 * 1024 * 1024) {
                cancelHook.Cancel();
              }
            }
          }
        })
      } catch (e) {
        expect(e.message).assertEqual('cancel downloadFile')
      }

      const res3 = await client.downloadFile({
        Bucket: TestBucket,
        Key: TEST_OBJECT_KEY,
        FilePath: filePath,
        CheckpointFile: checkpointPath,
        EnableCheckpoint: true,
        DataTransferListener: {
          DataTransferStatusChange(status){
            size2 += status.RWOnceBytes;
            console.log('size2 ===> ', size2)
          }
        }
      })
      const fileStat = await fs.stat(filePath)
      expect(fileStat.size).assertEqual(res.ContentLength);

      const checkpointPath2 = context.filesDir + '/c/d/cp2.json';
      const cancelHook2 = new CancelHook();
      const newKey = 'test-new' + getRandomNum();
      let count = 0;

      try {
        const res4 = await client.uploadFile({
          Bucket: TestBucket,
          Key: newKey,
          FilePath: filePath,
          CheckpointFile: checkpointPath2,
          UploadEventListener: {
            EventChange(event){
              expect(event.CheckpointFile).assertEqual(checkpointPath2)
              if (event.Type === UploadEventType.UploadPartSucceed) {
                count++
                if (count === 3) {
                  cancelHook2.Cancel();
                }
              }
            }
          },
          CancelHook: cancelHook2,
        })
      } catch (e) {
      }

      const res5 = await client.uploadFile({
        Bucket: TestBucket,
        Key: newKey,
        FilePath: filePath,
        CheckpointFile: checkpointPath2,
        EnableCheckpoint: true,
        UploadEventListener: {
          EventChange(event){
            if (event.Type === UploadEventType.UploadPartSucceed){
              count++
            }
          }
        },
      })
      expect(count).assertEqual(5);

      const res6 = await client.headObject({
        Bucket: TestBucket,
        Key: newKey,
      })
      expect(res6.HashCrc64ecma?.length && res6.HashCrc64ecma?.length > 0).assertTrue();
      expect(res.HashCrc64ecma).assertEqual(res6.HashCrc64ecma);
      console.log('crc ===> ', res6.HashCrc64ecma);
    })

    it('cancel_and_checkpoint_no_check_file_path', 0, async () => {
      // TEST_OBJECT_KEY 需要为 100 MiB 的对象
      const filePath = context.filesDir + '/a/b/test.txt';
      const cancelHook = new CancelHook();
      const res = await client.headObject({
        Bucket: TestBucket,
        Key: TEST_OBJECT_KEY,
      })

      let size1 = 0;
      let size2 = 0;
      try {
        const res2 = await client.downloadFile({
          Bucket: TestBucket,
          Key: TEST_OBJECT_KEY,
          FilePath: filePath,
          CancelHook: cancelHook,
          DataTransferListener: {
            DataTransferStatusChange(status){
              size1 += status.RWOnceBytes;
              console.log('size1 ===> ', size1)
              if (size1 > 40 * 1024 * 1024) {
                cancelHook.Cancel();
              }
            }
          }
        })
      } catch (e) {
        expect(e.message).assertEqual('cancel downloadFile')
      }

      const res3 = await client.downloadFile({
        Bucket: TestBucket,
        Key: TEST_OBJECT_KEY,
        FilePath: filePath,
        EnableCheckpoint: true,
        DataTransferListener: {
          DataTransferStatusChange(status){
            size2 += status.RWOnceBytes;
            console.log('size2 ===> ', size2)
          }
        }
      })
      const fileStat = await fs.stat(filePath)
      expect(size2 < res.ContentLength).assertTrue();
      expect(fileStat.size).assertEqual(res.ContentLength);

      const cancelHook2 = new CancelHook();
      const newKey = 'test-new' + getRandomNum();
      let count = 0;

      try {
        const res4 = await client.uploadFile({
          Bucket: TestBucket,
          Key: newKey,
          FilePath: filePath,
          UploadEventListener: {
            EventChange(event){
              if (event.Type === UploadEventType.UploadPartSucceed) {
                count++
                if (count === 3) {
                  cancelHook2.Cancel();
                }
              }
            }
          },
          CancelHook: cancelHook2,
        })
      } catch (e) {
      }

      const res5 = await client.uploadFile({
        Bucket: TestBucket,
        Key: newKey,
        FilePath: filePath,
        EnableCheckpoint: true,
        UploadEventListener: {
          EventChange(event){
            if (event.Type === UploadEventType.UploadPartSucceed){
              count++
            }
          }
        },
      })
      expect(count).assertEqual(5);

      const res6 = await client.headObject({
        Bucket: TestBucket,
        Key: newKey,
      })
      expect(res6.HashCrc64ecma?.length && res6.HashCrc64ecma?.length > 0).assertTrue();
      expect(res.HashCrc64ecma).assertEqual(res6.HashCrc64ecma);
      console.log('crc ===> ', res6.HashCrc64ecma);
    })

    it('cancel_and_checkpoint_task_num_3', 0, async () => {
      // TEST_OBJECT_KEY 需要为 1 GiB 的对象
      const filePath = context.filesDir + '/a/b/test.txt';
      const checkpointPath = context.filesDir + '/c/d/';
      const cancelHook = new CancelHook();
      const res = await client.headObject({
        Bucket: TestBucket,
        Key: TEST_OBJECT_KEY,
      })

      let size1 = 0;
      let size2 = 0;
      try {
        const res2 = await client.downloadFile({
          Bucket: TestBucket,
          Key: TEST_OBJECT_KEY,
          FilePath: filePath,
          TaskNum: 3,
          CancelHook: cancelHook,
          CheckpointFile: checkpointPath,
          DataTransferListener: {
            DataTransferStatusChange(status){
              size1 += status.RWOnceBytes;
              console.log('size1 ===> ', size1)
              if (size1 > 80 * 1024 * 1024) {
                cancelHook.Cancel();
              }
            }
          }
        })
      } catch (e) {
        expect(e.message).assertEqual('cancel downloadFile')
      }

      const res3 = await client.downloadFile({
        Bucket: TestBucket,
        Key: TEST_OBJECT_KEY,
        FilePath: filePath,
        TaskNum: 3,
        CheckpointFile: checkpointPath,
        EnableCheckpoint: true,
        DataTransferListener: {
          DataTransferStatusChange(status){
            size2 += status.RWOnceBytes;
            console.log('size2 ===> ', size2)
          }
        }
      })
      const fileStat = await fs.stat(filePath)
      expect(fileStat.size).assertEqual(res.ContentLength);

      const checkpointPath2 = context.filesDir + '/c/e/f';
      const cancelHook2 = new CancelHook();
      const newKey = 'test-new' + getRandomNum();
      let count = 0;

      try {
        const res4 = await client.uploadFile({
          Bucket: TestBucket,
          Key: newKey,
          FilePath: filePath,
          TaskNum: 3,
          CheckpointFile: checkpointPath2,
          UploadEventListener: {
            EventChange(event){
              expect(event.CheckpointFile).assertEqual(checkpointPath2)
              if (event.Type === UploadEventType.UploadPartSucceed) {
                count++
                if (count === 3) {
                  cancelHook2.Cancel();
                }
              }
            }
          },
          CancelHook: cancelHook2,
        })
      } catch (e) {
      }

      const res5 = await client.uploadFile({
        Bucket: TestBucket,
        Key: newKey,
        FilePath: filePath,
        TaskNum: 3,
        CheckpointFile: checkpointPath2,
        EnableCheckpoint: true,
        UploadEventListener: {
          EventChange(event){
            if (event.Type === UploadEventType.UploadPartSucceed){
              count++
            }
          }
        },
      })
      expect(count).assertEqual(5);

      const res6 = await client.headObject({
        Bucket: TestBucket,
        Key: newKey,
      })
      expect(res6.HashCrc64ecma?.length && res6.HashCrc64ecma?.length > 0).assertTrue();
      expect(res.HashCrc64ecma).assertEqual(res6.HashCrc64ecma);
      console.log('crc ===> ', res6.HashCrc64ecma);
    })
  })
}