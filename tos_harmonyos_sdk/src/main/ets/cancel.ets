/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

export class CancelHook {
  isAbort = false;
  isCanceled = false;
  Cancel(isAbort: boolean = false){
    this.isCanceled = true;
    this.isAbort = isAbort;
  }
}

export class CancelError extends Error {
  constructor(message: string) {
    super(message);
  }
}