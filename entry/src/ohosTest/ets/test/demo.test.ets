import { hilog } from '@kit.PerformanceAnalysisKit';
import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TosClient } from 'tos_harmonyos_sdk'
import { hashMd5ToStr, stringify } from 'tos_harmonyos_sdk/src/main/ets/crypto/index'
import { AK, SK, Endpoint, Region, TestBucket } from 'tos_harmonyos_sdk/env'
import { assertError, genRandomId, log } from './utils';
import { buffer } from '@kit.ArkTS';
import { abilityDelegatorRegistry } from '@kit.TestKit';

const context = abilityDelegatorRegistry.getAbilityDelegator().getAppContext();
export const filesDir = context.filesDir;


const client = new TosClient({
  accessKeyId: AK,
  accessKeySecret: SK,
  // securityToken: token,
  region: Region,
  endpoint: Endpoint,
});

export default function demoTest() {
  //let bucketName = genRandomId('put-object');
  describe('demoTest', () => {
    beforeAll(async  () => {
      // log('before all buketName: ' + bucketName)
      // await client.createBucket({
      //   Bucket: bucketName,
      // })
    })
    afterAll(async  () => {
      // await client.deleteBucket({
      //   Bucket: bucketName,
      // })
    })
    it('test-math-get-object', 0, async () => {
      const key = 'test-match.txt'
      const res =  await client.getObject({
        Bucket: TestBucket,
        Key: key,
      })

      await assertError(async () => {
        await client.getObject({
          Bucket: TestBucket,
          Key: key,
          IfNoneMatch: res.ETag
        })
      }, {statusCode:  304 })
    })
  })
}