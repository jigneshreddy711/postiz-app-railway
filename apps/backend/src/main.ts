import { initializeSentry } from '@gitroom/nestjs-libraries/sentry/initialize.sentry';
initializeSentry('backend', true);

import { loadSwagger } from '@gitroom/helpers/swagger/load.swagger';
import { json } from 'express';

import { Logger, ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import cookieParser from 'cookie-parser';
import { AppModule } from './app.module';

import { SubscriptionExceptionFilter } from '@gitroom/backend/services/auth/permissions/subscription.exception';
import { HttpExceptionFilter } from '@gitroom/nestjs-libraries/services/exception.filter';
import { ConfigurationChecker } from '@gitroom/helpers/configuration/configuration.checker';
import { startMcp } from '@gitroom/nestjs-libraries/chat/start.mcp';

process.env.TZ = 'UTC';

// ✅ Guard Temporal
if (process.env.ENABLE_TEMPORAL === 'true' && process.env.TEMPORAL_ADDRESS) {
  const { Runtime } = require('@temporalio/worker');
  Runtime.install({ shutdownSignals: [] });
}

async function start() {
  const app = await NestFactory.create(AppModule, {
    rawBody: true,
    cors: {
      credentials: !process.env.NOT_SECURED,
      allowedHeaders: [
        'Content-Type',
        'Authorization',
        'x-copilotkit-runtime-client-gql-version',
      ],
      exposedHeaders: [
        'reload',
        'onboarding',
        'activate',
        'x-copilotkit-runtime-client-gql-version',
      ],
      origin: [
        process.env.FRONTEND_URL,
        ...(process.env.MAIN_URL ? [process.env.MAIN_URL] : []),
      ],
    },
  });

  await startMcp(app);

  app.useGlobalPipes(new ValidationPipe({ transform: true }));
  app.use('/copilot/*', json({ limit: '50mb' }));
  app.use(cookieParser());

  app.useGlobalFilters(new SubscriptionExceptionFilter());
  app.useGlobalFilters(new HttpExceptionFilter());

  loadSwagger(app);

  const port = process.env.PORT || 3000;

  await app.listen(port, '0.0.0.0');
  Logger.log(`🚀 Backend running on port ${port}`);

  checkConfiguration();
}

function checkConfiguration() {
  const checker = new ConfigurationChecker();
  checker.readEnvFromProcess();
  checker.check();

  if (checker.hasIssues()) {
    checker.getIssues().forEach(issue =>
      Logger.warn(issue, 'Configuration issue')
    );
  }
}

start();
