import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/jvm/jvm_exception.dart';

void main() {
  test('parse exception with causes', () {
    final exception = JvmException.parse(javaExceptionWithCauses);
    expect(exception.description, 'Something bad happened');
    expect(exception.thread, null);
    expect(exception.type, 'javax.servlet.ServletException');
    expect(exception.stackTrace.length, 20);
    expect(exception.causes?.length, 3);
    expect(exception.suppressed?.length, null);
  });

  test('causes are parsed correctly', () {
    final exception = JvmException.parse(javaExceptionWithCauses);

    expect(exception.causes?.length, 3);
    final firstCause = exception.causes![0];
    final secondCause = exception.causes![1];
    final thirdCause = exception.causes![2];

    expect(firstCause.description, null);
    expect(firstCause.thread, null);
    expect(firstCause.type, 'com.example.myproject.MyProjectServletException');
    expect(firstCause.stackTrace.length, 7);
    expect(firstCause.causes, null);
    expect(firstCause.suppressed, null);

    expect(secondCause.description,
        'could not insert: [com.example.myproject.MyEntity]');
    expect(secondCause.thread, null);
    expect(secondCause.type,
        'org.hibernate.exception.ConstraintViolationException');
    expect(secondCause.stackTrace.length, 26);
    expect(secondCause.causes, null);
    expect(secondCause.suppressed, null);

    expect(thirdCause.description,
        'Violation of unique constraint MY_ENTITY_UK_1: duplicate value(s) for column(s) MY_COLUMN in statement [...]');
    expect(thirdCause.thread, null);
    expect(thirdCause.type, 'java.sql.SQLException');
    expect(thirdCause.stackTrace.length, 5);
    expect(thirdCause.causes, null);
    expect(thirdCause.suppressed, null);
  });

  test('parse exception with suppressed exceptions', () {
    final exception = JvmException.parse(exceptionWithSuppressedException);
    expect(exception.description, 'Main block');
    expect(exception.thread, 'main');
    expect(exception.type, 'java.lang.Exception');
    expect(exception.stackTrace.length, 1);

    expect(exception.causes, null);
    expect(exception.suppressed?.length, 2);
  });

  test('parse exception with causes and suppressed exceptions', () {
    final exception = JvmException.parse(causesAndSuppressedException);
    expect(exception.description, 'Main block');
    expect(exception.thread, 'main');
    expect(exception.type, 'java.lang.Exception');
    expect(exception.stackTrace.length, 1);

    expect(exception.causes?.length, 1);
    expect(exception.suppressed?.length, 1);
  });

  test('parse Flutter Android PlatformException', () {
    final exception = JvmException.parse(flutterAndroidPlatformException);
    expect(
      exception.description,
      "Unsupported value: '[Ljava.lang.StackTraceElement;@ba6feed' of type 'class [Ljava.lang.StackTraceElement;'",
    );
    expect(exception.thread, null);
    expect(exception.type, 'java.lang.IllegalArgumentException');
    expect(exception.stackTrace.length, 18);
    expect(exception.causes, null);
    expect(exception.suppressed, null);

    expect(exception.stackTrace[0].className,
        'io.flutter.plugin.common.StandardMessageCodec');
    expect(exception.stackTrace[0].method, 'writeValue');
    expect(exception.stackTrace[0].fileName, 'StandardMessageCodec.java');
    expect(exception.stackTrace[0].lineNumber, 292);
  });

  test('parse other Flutter Android PlatformException', () {
    final exception = JvmException.parse(otherFlutterAndroidPlatformException);
    expect(
      exception.description,
      "Unable to find resource ID #0x7f14000d",
    );
    expect(exception.thread, null);
    expect(exception.type, 'android.content.res.Resources\$NotFoundException');
    expect(exception.stackTrace.length, 19);
    expect(exception.causes, null);
    expect(exception.suppressed, null);

    expect(
        exception.stackTrace[0].className, 'android.content.res.ResourcesImpl');
    expect(exception.stackTrace[0].method, 'getResourceEntryName');
    expect(exception.stackTrace[0].fileName, 'ResourcesImpl.java');
    expect(exception.stackTrace[0].lineNumber, 493);
  });

  test('parse drops empty frames', () {
    final exception = JvmException.parse(platformExceptionWithEmptyStackFrames);
    expect(exception.stackTrace.length, 13);
    expect(exception.stackTrace.last.className,
        'com.android.internal.os.ZygoteInit');
    expect(exception.stackTrace.last.fileName, 'ZygoteInit.java');
    expect(exception.stackTrace.last.method, 'main');
    expect(exception.stackTrace.last.lineNumber, 936);
  });
}

const javaExceptionWithCauses = '''
javax.servlet.ServletException: Something bad happened
    at com.example.myproject.OpenSessionInViewFilter.doFilter(OpenSessionInViewFilter.java:60)
    at org.mortbay.jetty.servlet.ServletHandler\$CachedChain.doFilter(ServletHandler.java:1157)
    at com.example.myproject.ExceptionHandlerFilter.doFilter(ExceptionHandlerFilter.java:28)
    at org.mortbay.jetty.servlet.ServletHandler\$CachedChain.doFilter(ServletHandler.java:1157)
    at com.example.myproject.OutputBufferFilter.doFilter(OutputBufferFilter.java:33)
    at org.mortbay.jetty.servlet.ServletHandler\$CachedChain.doFilter(ServletHandler.java:1157)
    at org.mortbay.jetty.servlet.ServletHandler.handle(ServletHandler.java:388)
    at org.mortbay.jetty.security.SecurityHandler.handle(SecurityHandler.java:216)
    at org.mortbay.jetty.servlet.SessionHandler.handle(SessionHandler.java:182)
    at org.mortbay.jetty.handler.ContextHandler.handle(ContextHandler.java:765)
    at org.mortbay.jetty.webapp.WebAppContext.handle(WebAppContext.java:418)
    at org.mortbay.jetty.handler.HandlerWrapper.handle(HandlerWrapper.java:152)
    at org.mortbay.jetty.Server.handle(Server.java:326)
    at org.mortbay.jetty.HttpConnection.handleRequest(HttpConnection.java:542)
    at org.mortbay.jetty.HttpConnection\$RequestHandler.content(HttpConnection.java:943)
    at org.mortbay.jetty.HttpParser.parseNext(HttpParser.java:756)
    at org.mortbay.jetty.HttpParser.parseAvailable(HttpParser.java:218)
    at org.mortbay.jetty.HttpConnection.handle(HttpConnection.java:404)
    at org.mortbay.jetty.bio.SocketConnector\$Connection.run(SocketConnector.java:228)
    at org.mortbay.thread.QueuedThreadPool\$PoolThread.run(QueuedThreadPool.java:582)
Caused by: com.example.myproject.MyProjectServletException
    at com.example.myproject.MyServlet.doPost(MyServlet.java:169)
    at javax.servlet.http.HttpServlet.service(HttpServlet.java:727)
    at javax.servlet.http.HttpServlet.service(HttpServlet.java:820)
    at org.mortbay.jetty.servlet.ServletHolder.handle(ServletHolder.java:511)
    at org.mortbay.jetty.servlet.ServletHandler\$CachedChain.doFilter(ServletHandler.java:1166)
    at com.example.myproject.OpenSessionInViewFilter.doFilter(OpenSessionInViewFilter.java:30)
    ... 27 more
Caused by: org.hibernate.exception.ConstraintViolationException: could not insert: [com.example.myproject.MyEntity]
    at org.hibernate.exception.SQLStateConverter.convert(SQLStateConverter.java:96)
    at org.hibernate.exception.JDBCExceptionHelper.convert(JDBCExceptionHelper.java:66)
    at org.hibernate.id.insert.AbstractSelectingDelegate.performInsert(AbstractSelectingDelegate.java:64)
    at org.hibernate.persister.entity.AbstractEntityPersister.insert(AbstractEntityPersister.java:2329)
    at org.hibernate.persister.entity.AbstractEntityPersister.insert(AbstractEntityPersister.java:2822)
    at org.hibernate.action.EntityIdentityInsertAction.execute(EntityIdentityInsertAction.java:71)
    at org.hibernate.engine.ActionQueue.execute(ActionQueue.java:268)
    at org.hibernate.event.def.AbstractSaveEventListener.performSaveOrReplicate(AbstractSaveEventListener.java:321)
    at org.hibernate.event.def.AbstractSaveEventListener.performSave(AbstractSaveEventListener.java:204)
    at org.hibernate.event.def.AbstractSaveEventListener.saveWithGeneratedId(AbstractSaveEventListener.java:130)
    at org.hibernate.event.def.DefaultSaveOrUpdateEventListener.saveWithGeneratedOrRequestedId(DefaultSaveOrUpdateEventListener.java:210)
    at org.hibernate.event.def.DefaultSaveEventListener.saveWithGeneratedOrRequestedId(DefaultSaveEventListener.java:56)
    at org.hibernate.event.def.DefaultSaveOrUpdateEventListener.entityIsTransient(DefaultSaveOrUpdateEventListener.java:195)
    at org.hibernate.event.def.DefaultSaveEventListener.performSaveOrUpdate(DefaultSaveEventListener.java:50)
    at org.hibernate.event.def.DefaultSaveOrUpdateEventListener.onSaveOrUpdate(DefaultSaveOrUpdateEventListener.java:93)
    at org.hibernate.impl.SessionImpl.fireSave(SessionImpl.java:705)
    at org.hibernate.impl.SessionImpl.save(SessionImpl.java:693)
    at org.hibernate.impl.SessionImpl.save(SessionImpl.java:689)
    at sun.reflect.GeneratedMethodAccessor5.invoke(Unknown Source)
    at sun.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:25)
    at java.lang.reflect.Method.invoke(Method.java:597)
    at org.hibernate.context.ThreadLocalSessionContext\$TransactionProtectionWrapper.invoke(ThreadLocalSessionContext.java:344)
    at \$Proxy19.save(Unknown Source)
    at com.example.myproject.MyEntityService.save(MyEntityService.java:59)
    at com.example.myproject.MyServlet.doPost(MyServlet.java:164)
    ... 32 more
Caused by: java.sql.SQLException: Violation of unique constraint MY_ENTITY_UK_1: duplicate value(s) for column(s) MY_COLUMN in statement [...]
    at org.hsqldb.jdbc.Util.throwError(Unknown Source)
    at org.hsqldb.jdbc.jdbcPreparedStatement.executeUpdate(Unknown Source)
    at com.mchange.v2.c3p0.impl.NewProxyPreparedStatement.executeUpdate(NewProxyPreparedStatement.java:105)
    at org.hibernate.id.insert.AbstractSelectingDelegate.performInsert(AbstractSelectingDelegate.java:57)
    ... 54 more
''';

const exceptionWithSuppressedException = '''
Exception in thread "main" java.lang.Exception: Main block
  at Foo3.main(Foo3.java:7)
  Suppressed: Resource\$CloseFailException: Resource ID = 2
          at Resource.close(Resource.java:26)
          at Foo3.main(Foo3.java:5)
  Suppressed: Resource\$CloseFailException: Resource ID = 1
          at Resource.close(Resource.java:26)
          at Foo3.main(Foo3.java:5)
''';

const causesAndSuppressedException = '''
Exception in thread "main" java.lang.Exception: Main block
  at Foo4.main(Foo4.java:6)
  Suppressed: Resource2\$CloseFailException: Resource ID = 1
          at Resource2.close(Resource2.java:20)
          at Foo4.main(Foo4.java:5)
Caused by: java.lang.Exception: Rats, you caught me
          at Resource2\$CloseFailException.(Resource2.java:45)
          ... 2 more
''';

const flutterAndroidPlatformException = '''
java.lang.IllegalArgumentException: Unsupported value: '[Ljava.lang.StackTraceElement;@ba6feed' of type 'class [Ljava.lang.StackTraceElement;'
	at io.flutter.plugin.common.StandardMessageCodec.writeValue(StandardMessageCodec.java:292)
	at io.flutter.plugin.common.StandardMethodCodec.encodeSuccessEnvelope(StandardMethodCodec.java:59)
	at io.flutter.plugin.common.MethodChannel\$IncomingMethodCallHandler\$1.success(MethodChannel.java:267)
	at io.sentry.samples.flutter.MainActivity.configureFlutterEngine\$lambda-0(MainActivity.kt:40)
	at io.sentry.samples.flutter.MainActivity.lambda\$TiSaAm1LIEmKLVswI4BlR_5sw5Y(Unknown Source:0)
	at io.sentry.samples.flutter.-\$\$Lambda\$MainActivity\$TiSaAm1LIEmKLVswI4BlR_5sw5Y.onMethodCall(Unknown Source:2)
	at io.flutter.plugin.common.MethodChannel\$IncomingMethodCallHandler.onMessage(MethodChannel.java:262)
	at io.flutter.embedding.engine.dart.DartMessenger.invokeHandler(DartMessenger.java:296)
	at io.flutter.embedding.engine.dart.DartMessenger.lambda\$dispatchMessageToQueue\$0\$DartMessenger(DartMessenger.java:320)
	at io.flutter.embedding.engine.dart.-\$\$Lambda\$DartMessenger\$TsixYUB5E6FpKhMtCSQVHKE89gQ.run(Unknown Source:12)
	at android.os.Handler.handleCallback(Handler.java:938)
	at android.os.Handler.dispatchMessage(Handler.java:99)
	at android.os.Looper.loopOnce(Looper.java:210)
	at android.os.Looper.loop(Looper.java:299)
	at android.app.ActivityThread.main(ActivityThread.java:8138)
	at java.lang.reflect.Method.invoke(Native Method)
	at com.android.internal.os.RuntimeInit\$MethodAndArgsCaller.run(RuntimeInit.java:556)
	at com.android.internal.os.ZygoteInit.main(ZygoteInit.java:1037)''';

const otherFlutterAndroidPlatformException = '''
android.content.res.Resources\$NotFoundException: Unable to find resource ID #0x7f14000d
	at android.content.res.ResourcesImpl.getResourceEntryName(ResourcesImpl.java:493)
	at android.content.res.Resources.getResourceEntryName(Resources.java:2441)
	at com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin.getMappedNotificationChannel(FlutterLocalNotificationsPlugin.java:170)
	at com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin.getNotificationChannels(FlutterLocalNotificationsPlugin.java:32)
	at com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin.onMethodCall(FlutterLocalNotificationsPlugin.java:399)
	at be.j\$a.a(MethodChannel.java:18)
	at pd.c.l(DartMessenger.java:19)
	at pd.c.m(DartMessenger.java:42)
	at pd.c.h(Unknown Source:0)
	at pd.b.run(Unknown Source:12)
	at android.os.Handler.handleCallback(Handler.java:966)
	at android.os.Handler.dispatchMessage(Handler.java:110)
	at android.os.Looper.loopOnce(Looper.java:205)
	at android.os.Looper.loop(Looper.java:293)
	at android.app.ActivityThread.loopProcess(ActivityThread.java:9832)
	at android.app.ActivityThread.main(ActivityThread.java:9821)
	at java.lang.reflect.Method.invoke(Native Method)
	at com.android.internal.os.RuntimeInit\$MethodAndArgsCaller.run(RuntimeInit.java:586)
	at com.android.internal.os.ZygoteInit.main(ZygoteInit.java:1201)''';

const platformExceptionWithEmptyStackFrames = '''
java.lang.RuntimeException: Catch this platform exception!
    at io.sentry.samples.flutter.MainActivity\$configureFlutterEngine\$1.onMethodCall(MainActivity.kt:40)
    at io.flutter.plugin.common.MethodChannel\$IncomingMethodCallHandler.onMessage(MethodChannel.java:258)
    at io.flutter.embedding.engine.dart.DartMessenger.invokeHandler(DartMessenger.java:295)
    at io.flutter.embedding.engine.dart.DartMessenger.lambda\$dispatchMessageToQueue\$0\$io-flutter-embedding-engine-dart-DartMessenger(DartMessenger.java:322)
    at io.flutter.embedding.engine.dart.DartMessenger\$\$ExternalSyntheticLambda0.run(Unknown Source:12)
    at android.os.Handler.handleCallback(Handler.java:942)
    at android.os.Handler.dispatchMessage(Handler.java:99)
    at android.os.Looper.loopOnce(Looper.java:201)
    at android.os.Looper.loop(Looper.java:288)
    at android.app.ActivityThread.main(ActivityThread.java:7872)
    at java.lang.reflect.Method.invoke
    at com.android.internal.os.RuntimeInit\$MethodAndArgsCaller.run(RuntimeInit.java:548)
    at com.android.internal.os.ZygoteInit.main(ZygoteInit.java:936)

    ''';
