import { rcp } from '@kit.RemoteCommunicationKit'

// pages/xxx.ets
import { fileIo, fileIo as fs, ListFileOptions, ReadOptions } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { buffer, stream } from '@kit.ArkTS';
import { process } from '@kit.ArkTS';
import  { TosClient, TosClientError, TosServerError } from '@volcengine/tos_harmonyos_sdk'

// 获取应用文件路径
let context = getContext(this) as common.UIAbilityContext;

export const filesDir = context.filesDir;
const cacheDir = context.cacheDir;

const client = new TosClient({
  accessKeyId:'',
  accessKeySecret:'',
  endpoint: '',
  region: ''
})

export const writeFile = async (size: number, path: string, chunkSize = 1024) => {
  //const path = filesDir + '/test2.txt';
  const writableStream = fs.createStreamSync(path, "w+");
  let written = 0;

  let ok = true;
  let i = 0;
  let lastContent = '0';
  while (written < size && ok) {
    console.log('written w===>: ', written);
    i++;
    console.log('written i===>: ', i);
    const content = 'a'.repeat(chunkSize) //
    // 写入数据
    await writableStream.write(content, {
      offset: written
    })
    written += chunkSize;
    lastContent = content;
  }
  console.log('written===>: ', written)

  await writableStream.close();
  return path;
}

export  function handleError(error: Error) {
  if (error instanceof TosClientError) {
    console.log("UT Client Err Msg:" + error.message);
    console.log("UT Client Err Stack:"+ error.stack);
  } else if (error instanceof TosServerError) {
    console.log("UT  Request ID:"+  error.RequestID);
    console.log("UT Response Status Code:"+ error.StatusCode);
    console.log("UT Response Err Code:" + error.StatusCode);
    console.log("UT Response Err Msg:" + error.Message);
  } else {
    console.log("UT unexpected exception, message: " + error);
  }
}

class FdReadFile {
  readonly fd: number;

  constructor(fd: number) {
    this.fd = fd;
  }

  async read(buffer: ArrayBuffer): Promise<number> {
    return fileIo.read(this.fd, buffer);
  }
}

// 获取应用文件路径

export const genRandomId = () => {
  let id = '';

  for (let i = 0; i < 8; i++) {
    id += String(Math.floor(Math.random() * 10));
  }

  return 'tos-harmony-sdk-ut' + id;
};

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
          const path = '/data/storage/el2/base/haps/entry/files/test50M.txt';
          //await writeFile(1024 * 1024 * 50, path)
          console.log('hjp path: ', path)
          const stat = fs.statSync(path);
          console.log('stat ==> ', stat.size)
          const file = fs.openSync("/data/storage/el2/base/haps/entry/files/test50M.txt", fs.OpenMode.READ_ONLY);
          console.log('file ==> ', file.fd)
          try {
            const res = await client.putObject({
              Bucket:'dms-test-target',
              Key: 'test50M.txt',
              Content: new rcp.UploadFromStream(new FdReadFile(file.fd))
            })
            console.log('res===> ', res.RequestID)
          } catch (e) {
            handleError(e);
          }
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
          const path = '/data/storage/el2/base/haps/entry/files/test300M.txt'
          const res = await client.headBucket({
            Bucket:'dms-test-target',
          })
          await writeFile(300 * 1024 * 1024, path)
          console.log('head ===> ', res.Region);
          const stat = fs.statSync(path);
          console.log('stat ==> ', stat.size)
          const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
          let buf = buffer.alloc(300 * 1024 * 1024);
          try {
            fs.readSync(file.fd, buf.buffer)
          } catch (e) {
            console.log(e);
          }
          try {
            const res = await client.putObject({
              Bucket:'dms-test-target',
              Key: 'test300M.txt',
              Content: buf.buffer,
            })
            console.log('res===> ', res.RequestID)
          } catch (e) {
            handleError(e);
          }

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
        })
      }
    }
  }
}