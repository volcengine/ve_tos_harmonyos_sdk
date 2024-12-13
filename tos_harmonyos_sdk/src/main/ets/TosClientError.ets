/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

export class TosClientError extends Error {
  Cause?: Error;
  constructor(message: string, err?: Error) {
    super(message);
    this.Cause = err;
  }
}

export default TosClientError;