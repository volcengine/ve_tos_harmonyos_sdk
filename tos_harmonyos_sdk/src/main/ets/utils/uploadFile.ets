/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */
import { hashMd5 } from "../crypto";
import { CheckpointRichInfo, CheckpointRecord, Task } from "../types/inner";
import { fileIo as fs } from '@kit.CoreFileKit';

interface ParseCheckpointRecordInput {
  EnableCheckpoint?: boolean;
  CheckpointFile?: string;
  Bucket: string;
  Key: string
  FilePath: string
}

export const getDirName = (path: string) => {
  const dirNameArr = path.split('/')
  dirNameArr.pop();
  const dirName = dirNameArr.join('/');
  return dirName;
}

export const safeAccessFile = async (path: string) => {
  try {
    const res = await fs.access(path);
    return res;
  } catch (e) {
    return false;
  }
}

export const isDirectory = async (path: string) => {
  const isAccess = await safeAccessFile(path);
  if (!isAccess) {
    return path.endsWith('/');
  }

  const stat = await fs.stat(path);
  return stat.isDirectory();
}

function getDefaultCheckpointFilePath(bucket: string, key: string) {
  const originPath = `${key}.${hashMd5(`${bucket}.${key}`, 'hex')}.upload`;
  const normalizePath = originPath.replace(/[\\/]/g, '');
  return normalizePath;
}

export const safeParseCheckpointFile = async <T>(filePath: string): Promise<T | null> => {
  try {
    if (!(await fs.access(filePath))) {
      return null;
    }
    const content = await fs.readText(filePath);
    return JSON.parse(content) as T;
  } catch (err) {
    console.warn("checkpoint's content is not a valid JSON");
    return null;
  }
};


export const parseCheckpointRecord = async <T>(input: ParseCheckpointRecordInput): Promise<CheckpointRichInfo<T>> => {
  const cpri: CheckpointRichInfo<T> = {}
  if (input.CheckpointFile) {
    cpri.filePath = input.CheckpointFile;
  } else {
    const dirName = getDirName(input.FilePath);
    cpri.filePath = dirName + '/' + getDefaultCheckpointFilePath(input.Bucket, input.Key);
  }

  if (await isDirectory(cpri.filePath)) {
    const split = cpri.filePath.endsWith('/') ? '' : '/'
    cpri.filePath = cpri.filePath + split + getDefaultCheckpointFilePath(input.Bucket, input.Key);
  }

  if (cpri.filePath && input.EnableCheckpoint) {
    const record = await safeParseCheckpointFile<T>(cpri.filePath);

    if (record) {
      cpri.record = record
    }
  }
  return cpri;
}

// the part except last one must be >= 5 MB
// the last part is no size limit
export const MIN_PART_SIZE_EXCEPT_LAST_ONE = 5 * 1024 * 1024;
export const MAX_PART_NUMBER = 10000;

export const calculateSafePartSize = (
  totalSize: number,
  expectPartSize: number,
  showWarning = false
) => {
  let partSize = expectPartSize;
  if (expectPartSize < MIN_PART_SIZE_EXCEPT_LAST_ONE) {
    partSize = MIN_PART_SIZE_EXCEPT_LAST_ONE;
    if (showWarning) {
      console.warn(
        `partSize has been set to ${partSize}, because the partSize you provided is less than the minimal size of multipart`
      );
    }
  }
  const minSize = Math.ceil(totalSize / MAX_PART_NUMBER);
  if (expectPartSize < minSize) {
    partSize = minSize;
    if (showWarning) {
      console.warn(
        `partSize has been set to ${partSize}, because the partSize you provided causes the number of part excesses 10,000`
      );
    }
  }

  return partSize;
};

/**
 * 即使 totalSize 是 0，也需要一个 Part，否则 Server 端会报错 read request body failed
 */
export  function getAllTasks(totalSize: number, partSize: number) {
  const tasks: Task[] = [];
  for (let i = 0; ; ++i) {
    const offset = i * partSize;
    const currPartSize = Math.min(partSize, totalSize - offset);

    tasks.push({
      offset,
      partSize: currPartSize,
      partNumber: i + 1,
    });

    if ((i + 1) * partSize >= totalSize) {
      break;
    }
  }

  return tasks;
}
