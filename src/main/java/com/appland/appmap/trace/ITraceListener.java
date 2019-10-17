package com.appland.appmap.trace;

import java.lang.reflect.Method;
import javassist.CtClass;

import java.util.List;


interface ITraceListener {
  void onClassLoad(CtClass classType);

  void onExceptionThrown(Exception exception);

  void onMethodInvoked(Integer methodId, Object selfValue, Object[] params);

  void onMethodReturned(Integer methodId, Object returnValue);

  void onSqlQuery();

  void onHttpRequest();
}