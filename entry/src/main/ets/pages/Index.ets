import { AK, SK, Endpoint,Region } from 'tos_harmonyos_sdk/env'
import { rcp } from '@kit.RemoteCommunicationKit'

// pages/xxx.ets
import { fileIo as fs, ListFileOptions, ReadOptions } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { buffer, stream } from '@kit.ArkTS';
import {
  CreateMultipartUploadOutput,
  StorageClassType, TosClient, TosClientError, TosServerError,
  UploadedPart } from 'tos_harmonyos_sdk';
import { TestBucket, TestCallBackUrl } from 'tos_harmonyos_sdk/env';
import { request } from '@kit.BasicServicesKit';

// 获取应用文件路径
let context = getContext(this) as common.UIAbilityContext;

export const filesDir = context.filesDir;
const cacheDir = context.cacheDir;

export const writeFile = async (size: number, path: string, chunkSize = 1024) => {
  //const path = filesDir + '/test2.txt';
  const writableStream = fs.createStreamSync(path, "w+");
  let written = 0;

  let ok = true;
  let i = 0;
  let lastContent = '0';
  while (written < size && ok) {
    console.log('written w: ', written);
    i++;
    console.log('written i: ', i);
    const content = 'a'.repeat(chunkSize) //
    // 写入数据
    await writableStream.write(content, {
      offset: written
    })
    written += chunkSize;
    lastContent = content;
  }
  console.log('written: ', written)

  await writableStream.close();
  return path;
}


// 获取应用文件路径

export const genRandomId = () => {
  let id = '';

  for (let i = 0; i < 8; i++) {
    id += String(Math.floor(Math.random() * 10));
  }

  return 'tos-harmony-sdk-ut' + id;
};

function handleError(error: Error) {
  if (error instanceof TosClientError) {
    console.log("hjp Client Err Msg:", error.message);
    console.log("hjp Client Err Stack:", error.stack);
  } else if (error instanceof TosServerError) {
    console.log("hjp Request ID:", error.RequestID);
    console.log("hjp Response Err Code:", error.StatusCode);
    console.log("hjp Response Err Msg:", error.Message);
  } else {
    console.log("hjp unexpected exception, message: ", error.message);
    console.log("hjp unexpected exception, message: ", error.stack);
  }
}

const client = new TosClient({
  accessKeyId: AK,
  accessKeySecret: SK,
  // securityToken: token,
  region: Region, // 填写 Bucket 所在地域。以华北2（北京)为例，"Provide your region" 填写为 cn-beijing。
  endpoint: Endpoint, // 填写域名地址
  requestTimeout: 1000 * 60 * 60 * 60
});

@Entry
@Component
struct Index {
  @State message: string = 'Hello World';
  @State count: number = 0

  build() {
    Row() {
      Column() {
        Text(`${this.count}`)
        Button() {
          Text('预签名2')
        }
        .type(ButtonType.Capsule)
        .width('100%')
        .margin({
          top: 20
        })
        .height('5%')
        .width('40%')
        .backgroundColor('#0D9FFB')
        .onClick(async () => {
          const path = '/data/storage/el2/base/haps/entry/files/test2G.txt';
          await writeFile(1024 * 1024 * 1024 * 3, path)
          console.log('hjp path: ', path)
        })
        Button() {
          Text('产生512M')
        }
        .type(ButtonType.Capsule)
        .width('100%')
        .margin({
          top: 20
        })
        .height('5%')
        .width('40%')
        .backgroundColor('#0D9FFB')
        .onClick(async () => {
          const path = '/data/storage/el2/base/haps/entry/files/test20M.txt';
          await writeFile(1024 * 1024 * 200, path)
          console.log('hjp path: ', path)
        })

        Button() {
          Text('流式')
        }
        .type(ButtonType.Capsule)
        .width('100%')
        .margin({
          top: 20
        })
        .height('5%')
        .width('40%')
        .backgroundColor('#0D9FFB')
        .onClick(async () => {
          const path = '/data/storage/el2/base/haps/entry/files/test20M.txt';
          const stat = fs.statSync(path)
          console.log('hjp stat size: ', stat.size)
          const path2 = '/data/storage/el2/base/haps/entry/files/test2G.txt';
          const uploadFromStream = new rcp.UploadFromStream(fs.createStreamSync(path2, 'r+'))
          try {
            const res = await client.putObject({
              Bucket: 'dms-test-target',
              Key: 'rcp/test-rcp-upload-stream-3-G',
              Content: uploadFromStream,
            })
            console.log('hjp res: ', res.HashCrc64ecma)
          } catch (e) {
            handleError(e)
          }

        })

        Button() {
          Text('预签名3')
        }
        .type(ButtonType.Capsule)
        .width('100%')
        .margin({
          top: 20
        })
        .height('5%')
        .width('40%')
        .backgroundColor('#0D9FFB')
        .onClick(async () => {
          this.count++;
        })
        Button() {
          Text('分片')
        }
        .type(ButtonType.Capsule)
        .width('100%')
        .margin({
          top: 20
        })
        .height('5%')
        .width('40%')
        .backgroundColor('#0D9FFB')
        .onClick(async () => {
          const path = '/data/storage/el2/base/haps/entry/files/test20M.txt';
          const key = 'test-5-G-stream-600'
          let res: CreateMultipartUploadOutput;
          try {
            res = await client.createMultipartUpload({
              Bucket: 'dms-test-target',
              Key: key,
            })
          } catch (e) {
            handleError(e);
            return;
          }

          console.log('create part: ', res.UploadId)

          const buf = buffer.from('a'.repeat(1024 * 1024 * 20));
          for (let i = 0; i < 600; i++) {
            try {
              await client.uploadPart({
                Bucket: 'dms-test-target',
                Key: key,
                PartNumber: i + 1,
                UploadID: res.UploadId,
                Content: buf.buffer//fs.createReadStream(path)
              })
            } catch (e) {
              handleError(e);
            }
            console.log('part: ', i);
          }

          try {
            await client.completeMultipartUpload({
              Bucket: 'dms-test-target',
              Key: key,
              UploadID: res.UploadId,
              CompleteAll: true,
            })
          } catch (e) {
            handleError(e)
          }
          console.log('part: complete')
        })

        Button() {
          Text('分片2')
        }
        .type(ButtonType.Capsule)
        .width('100%')
        .margin({
          top: 20
        })
        .height('5%')
        .width('40%')
        .backgroundColor('#0D9FFB')
        .onClick(async () => {
          const path = '/data/storage/el2/base/haps/entry/files/test-get-object.txt';
          try {
            await client.putObject({
              Bucket: TestBucket,
              Key: 'test-123-abc',
              Content: buffer.from('abcdefghjjl你好123#%#……#¥……¥#634？？字符12111asjdaklllllaa').buffer
            })
          } catch (e) {
            handleError(e)
          }
        })
      }
    }
  }
}