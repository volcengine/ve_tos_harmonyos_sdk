/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

export enum DataTransferType {
  Started = 'Started',
  RW = 'RW',
  Succeed = 'Succeed',
  Failed = 'Failed',
}

export interface DataTransferStatus {
  ConsumedBytes: number // 已读/写字节数
  TotalBytes: number// 总字节数
  RWOnceBytes: number // 本次读写字节数
  Type: DataTransferType
}

export interface DataTransferListener {
  DataTransferStatusChange: (status: DataTransferStatus) => void
}