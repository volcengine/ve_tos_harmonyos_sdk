/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TosClient } from '../../../main/ets/client'
import { AK, SK, Endpoint, KMSMasterKeyID, MultiVersionBucket } from '../../../../env'
import { assertError, genRandomId, log } from './utils'
import { GetBucketEncryptionOutput } from '../../../../Index';
import { ListObjectDeleteMarkerItem, ListObjectsVersionItem, ObjectTobeDeleted } from '../../../main/ets/types/model2';
import { buffer } from '@kit.ArkTS';

const client = new TosClient({
  accessKeyId: AK,
  accessKeySecret: SK,
  // securityToken: token,
  region: Endpoint,
  endpoint: Endpoint,
});

export default function multiObjectsTest() {
  let bucketName = genRandomId();
  beforeAll(async () => {
    log('before all')
    await client.createBucket({
      Bucket: bucketName,
    })
  })

  afterAll(async () => {
    try {
      await client.deleteBucket({
        Bucket: bucketName,
      })
      log('delete bucket success: ' + bucketName)
    } catch (e) {
      log('delete bucket error: ' + bucketName)
    }
  })

  describe('multi_objects_test', () => {
    it('multi_objects_test', 0, async () => {
      const Count = 25;
      const keys = new Array(Count).fill(0).map((_: number, i) => 'test' + String(i).padStart(3, '0'))
      for (let k of keys) {
        await client.putObject({
          Bucket: bucketName,
          Key: k,
          Content: buffer.from('123').buffer,
        })
      }
      const res = await client.listObjectsType2({
        Bucket: bucketName,
        Prefix: 'test0',
      })
      for (let i = 0; i < 10; i++) {
        expect(res.Contents[i].Key).assertEqual('test' + String(i).padStart(3, '0'));
      }
      let token: string | undefined;
      let j = 0;
      let outputKeys: string[] = [];
      while (true) {
        const res = await client.listObjectsType2({
          Bucket: bucketName,
          Prefix: 'test',
          MaxKeys: 10,
          ContinuationToken: token
        })
        j++;
        if (j <= 2) {
          expect(res.Contents.length).assertEqual(10);
        } else if (j === 3) {
          expect(res.Contents.length).assertEqual(5);
          expect(res.IsTruncated).assertEqual(false);
        }
        outputKeys = outputKeys.concat(res.Contents.map(c => c.Key))
        token = res.NextContinuationToken;
        if (!res.NextContinuationToken) {
          break;
        }
      }
      outputKeys.sort((a, b) => {
        return a.localeCompare(b)
      })
      log('outputKeys: ' + JSON.stringify(outputKeys))
      expect(outputKeys).assertDeepEquals(keys);
      const res2 = await client.deleteMultiObjects({
        Bucket: bucketName,
        Objects: keys.map(item => new ObjectTobeDeleted(item))
      })
      const deleteKeys = res2.Deleted.map(item => item.Key).sort((a, b) => {
        return a.localeCompare(b)
      })
      expect(deleteKeys).assertDeepEquals(keys)

      // test other params
      const res3 = await client.listObjectsType2({
        Bucket: bucketName,
        Delimiter: 'aa',
        EncodingType: 'url'
      })
      expect(res3.EncodingType).assertEqual('url');
      expect(res3.Delimiter).assertEqual("aa");
    })
    it('list_objects_type2_params', 0, async () => {
      const res = await client.listObjectsType2({
        Bucket: bucketName,
        Delimiter: '你',
        Prefix: '中文测试'
      })
      expect(res.Prefix).assertEqual('中文测试')
      expect(res.Delimiter).assertEqual('你')
    })
    it('multi_objects_version_test', 0, async  () => {
      const prefix = 'sdk-test' + genRandomId();
      log('multi_objects_version_test prefix: ' + prefix)
      for (let i = 0; i < 21; i++) {
        await client.putObject({
          Bucket: MultiVersionBucket,
          Key: `${prefix}/file` + i,
          Content: buffer.from('123').buffer,
        })
      }
      // await client.deleteObject({
      //   Bucket: MultiVersionBucket,
      //   Key: `${prefix}/file` + 0,
      // })
      let versions: ListObjectsVersionItem[] = [];
      let deleteMarkers: ListObjectDeleteMarkerItem[] = [];
      let versionIdMarker = '';
      let keyMarker = '';
      let count = 0;
      while (true) {
        const res = await client.listObjectVersions({
          Bucket: MultiVersionBucket,
          Prefix: prefix,
          MaxKeys: 10,
          VersionIDMarker: versionIdMarker,
          KeyMarker: keyMarker
        })
        expect(res.MaxKeys).assertEqual(10);
        expect(res.Prefix).assertEqual(prefix);
        expect(res.VersionIdMarker).assertEqual(versionIdMarker);
        expect(res.KeyMarker).assertEqual(keyMarker);
        count++;
        deleteMarkers = deleteMarkers.concat(res.DeleteMarkers);
        versions = versions.concat(res.Versions);
        if (!res.NextVersionIdMarker || !res.NextKeyMarker) {
          break;
        }
        versionIdMarker = res.NextVersionIdMarker;
        keyMarker = res.NextKeyMarker;
      }
      const objectsTobeDelted: ObjectTobeDeleted[] = []
      versions.forEach(v => {
        objectsTobeDelted.push(new ObjectTobeDeleted(v.Key, v.VersionId))
      })
      deleteMarkers.forEach(d => {
        objectsTobeDelted.push(new ObjectTobeDeleted(d.Key, d.VersionId))
      })
      // 应该列举 3 次
      expect(count).assertEqual(3);
      expect(versions.length).assertEqual(21);
      expect(deleteMarkers.length).assertEqual(0);
      const res3 = await client.deleteMultiObjects({
        Bucket: MultiVersionBucket,
        Objects: objectsTobeDelted
      })
      expect(res3.Deleted.length).assertEqual(21);

      // test others params
      const res2 = await client.listObjectVersions({
        Bucket: MultiVersionBucket,
        Delimiter: 'aa',
        EncodingType: 'url'
      })
      // expect(res2.CommonPrefixes[0].Prefix).assertEqual('test/');
      expect(res2.Delimiter).assertEqual('aa');
      expect(res2.EncodingType).assertEqual('url');
    })
  })
}