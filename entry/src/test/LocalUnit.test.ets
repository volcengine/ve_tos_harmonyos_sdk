import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';

export default function localUnitTest() {
  describe('localUnitTest', () => {
    // Defines a test suite. Two parameters are supported: test suite name and test suite function.
    beforeAll(() => {
      // Presets an action, which is performed only once before all test cases of the test suite start.
      // This API supports only one parameter: preset action function.
    });
    beforeEach(() => {
      // Presets an action, which is performed before each unit test case starts.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: preset action function.
    });
    afterEach(() => {
      // Presets a clear action, which is performed after each unit test case ends.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: clear action function.
    });
    afterAll(() => {
      // Presets a clear action, which is performed after all test cases of the test suite end.
      // This API supports only one parameter: clear action function.
    });
    it('assertContain', 0, () => {
      interface ResponseDataBase {
        status: number;
      }
      interface CreateBucketResponseData extends ResponseDataBase {
        data: string[];
      }
      interface RequestInfo {
        StatusCode: number;
      }
      interface CreateBucketOutput extends RequestInfo {
        Location: string;
      }
      const withStatusCode = <T extends Partial<RequestInfo>>(out: T, data: ResponseDataBase) => {
        const finalOut = out;
        finalOut.StatusCode = data.status;
        return finalOut as Required<T>;
      };
      const createBucket  = (): CreateBucketOutput => {
        const res: CreateBucketResponseData = {
          status: 200,
          data: ['cn-beijing']
        };
        const result = {
          Location: '12'
        } as CreateBucketOutput;
        const result2 = withStatusCode(result, res);
        return result2;
      }
      const res = createBucket();
      res.Location;
      res.StatusCode;
      console.log('>>>>', JSON.stringify(createBucket()));
    });
  });
}