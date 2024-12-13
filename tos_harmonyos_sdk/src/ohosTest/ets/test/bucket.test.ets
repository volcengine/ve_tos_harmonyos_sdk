/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TosClient } from '../../../main/ets/client'
import { AK, SK, AccountId, Region, Endpoint, InnerEndpoint } from '../../../../env'
import { genRandomId, log } from './utils'
import { AzRedundancyType, StorageClassType, VersioningStatusType } from '../../../../Index';

const client = new TosClient({
  accessKeyId: AK,
  accessKeySecret: SK,
  // securityToken: token,
  region: Region,
  endpoint: Endpoint,
});

export default function bucketTest() {
  describe('test_bucket_base_api', () => {
    // Defines a test suite. Two parameters are supported: test suite name and test suite function.
    beforeAll(() => {
      // Presets an action, which is performed only once before all test cases of the test suite start.
      // This API supports only one parameter: preset action function.
    })
    beforeEach(() => {
      // Presets an action, which is performed before each unit test case starts.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: preset action function.
    })
    afterEach(() => {
      // Presets a clear action, which is performed after each unit test case ends.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: clear action function.
    })
    afterAll(() => {
      // Presets a clear action, which is performed after all test cases of the test suite end.
      // This API supports only one parameter: clear action function.
    })
    it('createBucket', 0, async  () => {
      hilog.info(0x0000, 'testTag', '%{public}s', 'it begin');
      const bucketName = genRandomId();
      const res = await client.createBucket({
        Bucket: bucketName
      })
      expect(res.StatusCode).assertEqual(200)
      expect(res.RequestID.length > 0).assertTrue();
      expect(!!res.Headers).assertTrue();
      const headBucketRes = await client.headBucket({
        Bucket: bucketName,
      })
      expect(headBucketRes.StorageClass).assertEqual(StorageClassType.StorageClassStandard)
      expect(headBucketRes.Region).assertEqual(Region);

      const res2 = await client.deleteBucket({
        Bucket: bucketName,
      })
      // 错误码为2xx
      hilog.info(0x0000, 'testTag', '%{public}s', `deleteBucket StatusCode: ${res2.StatusCode}`);
      expect(res2.StatusCode).assertLess(300)

      const res3 = await client.listBuckets();
      expect(res3.Owner?.ID).assertEqual(AccountId)
      expect(res3.Buckets.some(bkt => bkt.Name === bucketName)).assertFalse();
    })

    it('test_bucket_projectName', 0, async  () => {
      const bucketName = genRandomId();
      const ProjectName = 'test-hujinpu'
      const res = await client.createBucket({
        Bucket: bucketName,
        ProjectName,
      })
      expect(res.StatusCode).assertEqual(200)
      const res2 = await client.headBucket({
        Bucket: bucketName,
      })
      expect(res2.ProjectName).assertEqual(ProjectName);

      const res3 = await client.listBuckets({
        ProjectName,
      })
      expect(res3.Buckets.some(bkt => bkt.Name === bucketName)).assertTrue()
      expect(res3.Owner?.ID).assertEqual(AccountId)

      await client.deleteBucket({
        Bucket: bucketName,
      })

      const res4 = await client.listBuckets({
        ProjectName,
      })

      expect(res4.Buckets.some(bkt => bkt.Name === bucketName)).assertFalse()
      expect(res4.Owner?.ID).assertEqual(AccountId)
    })

    it('test_bucket_storageClass', 0, async () => {
      const runCase = async (StorageClass?: StorageClassType) => {
        const bucketName = genRandomId();
        await client.createBucket({
          Bucket: bucketName,
          StorageClass,
        })
        const res = await client.headBucket({
          Bucket: bucketName
        })
        // StorageClass 默认值为 StorageClassStandard
        if (!StorageClass) {
          hilog.info(0x0000, 'testTag', '%{public}s', `test_bucket_storageClass: no StorageClass`);
          expect(res.StorageClass).assertEqual(StorageClassType.StorageClassStandard);
        } else {
          hilog.info(0x0000, 'testTag', '%{public}s', `test_bucket_storageClass: ${StorageClass}`);
          expect(res.StorageClass).assertEqual(StorageClass);
        }

        await client.deleteBucket({
          Bucket: bucketName,
        })
      }

      await runCase();
      await runCase(StorageClassType.StorageClassStandard)
      await runCase(StorageClassType.StorageClassIa);
      // 归档闪回
      await runCase(StorageClassType.StorageClassArchiveFr)
      // 归档
      await runCase(StorageClassType.StorageClassArchive)
      // 冷归档
      await runCase(StorageClassType.StorageClassColdArchive);
    })

    it('test_az_redundancy', 0, async () => {
      const runCase = async  (az: AzRedundancyType) => {
        log(`test_az_redundancy: ${az}`);
        const bucketName = genRandomId();
        await client.createBucket({
          Bucket: bucketName,
          AzRedundancy: az,
        })
        const res = await client.headBucket({
          Bucket: bucketName,
        })
        expect(res.AzRedundancy).assertEqual(az);
        await client.deleteBucket({
          Bucket: bucketName,
        })
      }
      await runCase(AzRedundancyType.AzRedundancySingleAz);
      await runCase(AzRedundancyType.AzRedundancyMultiAz);
    })

    it('getBucketLocation', 0, async () => {
      const bucketName = genRandomId();
      await client.createBucket({
        Bucket: bucketName,
      })
      const res = await client.getBucketLocation({ Bucket: bucketName });
      expect(res.Region).assertEqual(Region);
      expect(res.ExtranetEndpoint).assertEqual(Endpoint);
      expect(res.IntranetEndpoint).assertEqual(InnerEndpoint);
      await client.deleteBucket({
        Bucket: bucketName,
      })
    })

    it('test_bucket_versioning', 0, async () => {
      const bucketName = genRandomId();
      await client.createBucket({
        Bucket: bucketName,
      })
      const res = await client.getBucketVersioning({
        Bucket: bucketName,
      });
      expect(res.Status).assertEqual(VersioningStatusType.VersioningStatusNotSet);
      await client.putBucketVersioning({
        Bucket: bucketName,
        Status: VersioningStatusType.VersioningStatusEnabled,
      })
      const res2 = await client.getBucketVersioning({
        Bucket: bucketName,
      });
      expect(res2.Status).assertEqual(VersioningStatusType.VersioningStatusEnabled);
      await client.putBucketVersioning({
        Bucket: 'fe-e2e-test-multiple-version',
        Status: VersioningStatusType.VersioningStatusSuspended,
      })
      const res3 = await client.getBucketVersioning({
        Bucket: 'fe-e2e-test-multiple-version',
      });
      expect(res3.Status).assertEqual(VersioningStatusType.VersioningStatusSuspended);

      await client.putBucketVersioning({
        Bucket: 'fe-e2e-test-multiple-version',
        Status: VersioningStatusType.VersioningStatusEnabled,
      })
      // const res4 = await client.getBucketVersioning({
      //   Bucket: 'fe-e2e-test-multiple-version',
      // });
      //expect(res4.Status).assertEqual(VersioningStatusType.VersioningStatusEnabled);
    })
  })
}