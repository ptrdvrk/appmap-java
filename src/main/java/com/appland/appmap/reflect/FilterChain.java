package com.appland.appmap.reflect;

import java.lang.reflect.Method;

public class FilterChain extends ReflectiveType {
  private final Method fnDoFilter;

  public FilterChain(Object self) {
    super(self);

    fnDoFilter = getMethodByClassNames("doFilter",
                                       "javax.servlet.ServletRequest",
                                       "javax.servlet.ServletResponse");
  }

  public void doFilter(Object request, Object response) {
    if (fnDoFilter != null) {
      invokeWrappedMethod(fnDoFilter, request, response);
    }
  }
}
