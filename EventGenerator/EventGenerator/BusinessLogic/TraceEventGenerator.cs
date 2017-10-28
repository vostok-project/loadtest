﻿using System.Threading.Tasks;
using Vostok.Tracing;

namespace EventGenerator.BusinessLogic
{
    public class TraceEventGenerator : IEventGenerator
    {
        public Task Generate(int count)
        {
            using (var spanBuilder = Trace.BeginSpan())
            {
                spanBuilder.SetAnnotation(TracingAnnotationNames.Operation, "Generate Trace");
                spanBuilder.SetAnnotation(TracingAnnotationNames.Kind, "loadtest");
                spanBuilder.SetAnnotation(TracingAnnotationNames.Service, "event-generator");
                spanBuilder.SetAnnotation(TracingAnnotationNames.Host, "localhost");
                spanBuilder.SetAnnotation(TracingAnnotationNames.HttpUrl, "send");
                spanBuilder.SetAnnotation(TracingAnnotationNames.HttpRequestContentLength, 1024);
                spanBuilder.SetAnnotation(TracingAnnotationNames.HttpResponseContentLength, 2048);
                spanBuilder.SetAnnotation(TracingAnnotationNames.HttpCode, 200);
            }
            return Task.FromResult(0);
        }
    }
}