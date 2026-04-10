package com.hireright.sourceintelligence.service.extraction;

import com.hireright.sourceintelligence.api.dto.ParchmentRecord;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Arrays;
import java.util.Collections;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class DataExtractionProcessorFactoryTest {

    private DataExtractionProcessorFactory factory;

    @Test
    void constructor_WithEmptyList_ShouldInitializeSuccessfully() {
        List<DataExtractionProcessor<?>> processors = Collections.emptyList();

        factory = new DataExtractionProcessorFactory(processors);

        assertNotNull(factory);
    }

    @Test
    void getProcessor_WithEmptyProcessorsList_ShouldThrowException() {
        List<DataExtractionProcessor<?>> processors = Collections.emptyList();
        factory = new DataExtractionProcessorFactory(processors);

        IllegalArgumentException exception = assertThrows(IllegalArgumentException.class,
                () -> factory.getProcessor("parchment"));

        assertTrue(exception.getMessage().contains("Unsupported Data Extraction type: 'parchment'"));
        assertTrue(exception.getMessage().contains("Available types: none"));
    }

    @Test
    void getSupportedTypes_WithEmptyProcessors_ShouldReturnNone() {
        List<DataExtractionProcessor<?>> processors = Collections.emptyList();
        factory = new DataExtractionProcessorFactory(processors);

        String supportedTypes = factory.getSupportedTypes();

        assertEquals("none", supportedTypes);
    }

    @Test
    void isSupported_WithEmptyProcessorsList_ShouldReturnFalse() {
        List<DataExtractionProcessor<?>> processors = Collections.emptyList();
        factory = new DataExtractionProcessorFactory(processors);

        boolean result = factory.isSupported("parchment");

        assertFalse(result);
    }

    @Test
    void getProcessor_WithValidType_ShouldReturnCorrectProcessor() {
        DataExtractionProcessor<ParchmentRecord> mockProcessor = mock(DataExtractionProcessor.class);
        when(mockProcessor.getDataExtractionTypeType()).thenReturn("parchment");
        when(mockProcessor.supports("parchment")).thenReturn(true);

        List<DataExtractionProcessor<?>> processors = Arrays.asList(mockProcessor);
        factory = new DataExtractionProcessorFactory(processors);

        DataExtractionProcessor<?> result = factory.getProcessor("parchment");

        assertNotNull(result);
        assertEquals(mockProcessor, result);
    }

    @Test
    void getProcessor_WithNullType_ShouldThrowException() {
        List<DataExtractionProcessor<?>> processors = Collections.emptyList();
        factory = new DataExtractionProcessorFactory(processors);

        IllegalArgumentException exception = assertThrows(IllegalArgumentException.class,
                () -> factory.getProcessor(null));

        assertTrue(exception.getMessage().contains("Data Extraction type cannot be null or empty"));
    }

    @Test
    void getProcessor_WithEmptyType_ShouldThrowException() {
        List<DataExtractionProcessor<?>> processors = Collections.emptyList();
        factory = new DataExtractionProcessorFactory(processors);

        IllegalArgumentException exception = assertThrows(IllegalArgumentException.class,
                () -> factory.getProcessor(""));

        assertTrue(exception.getMessage().contains("Data Extraction type cannot be null or empty"));
    }

    @Test
    void getProcessor_WithUnsupportedType_ShouldThrowException() {
        DataExtractionProcessor<ParchmentRecord> mockProcessor = mock(DataExtractionProcessor.class);
        when(mockProcessor.getDataExtractionTypeType()).thenReturn("parchment");
        when(mockProcessor.supports("parchment")).thenReturn(true);
        when(mockProcessor.supports("clearinghouse")).thenReturn(false);

        List<DataExtractionProcessor<?>> processors = Arrays.asList(mockProcessor);
        factory = new DataExtractionProcessorFactory(processors);

        IllegalArgumentException exception = assertThrows(IllegalArgumentException.class,
                () -> factory.getProcessor("clearinghouse"));

        assertTrue(exception.getMessage().contains("Unsupported Data Extraction type: 'clearinghouse'"));
        assertTrue(exception.getMessage().contains("Available types: parchment"));
    }

    @Test
    void getSupportedTypes_WithMultipleProcessors_ShouldReturnAllTypes() {
        DataExtractionProcessor<?> processor1 = mock(DataExtractionProcessor.class);
        when(processor1.getDataExtractionTypeType()).thenReturn("parchment");

        DataExtractionProcessor<?> processor2 = mock(DataExtractionProcessor.class);
        when(processor2.getDataExtractionTypeType()).thenReturn("clearinghouse");

        List<DataExtractionProcessor<?>> processors = Arrays.asList(processor1, processor2);
        factory = new DataExtractionProcessorFactory(processors);

        String supportedTypes = factory.getSupportedTypes();

        assertTrue(supportedTypes.contains("parchment"));
        assertTrue(supportedTypes.contains("clearinghouse"));
    }

    @Test
    void isSupported_WithSupportedType_ShouldReturnTrue() {
        DataExtractionProcessor<ParchmentRecord> mockProcessor = mock(DataExtractionProcessor.class);
        when(mockProcessor.supports("parchment")).thenReturn(true);

        List<DataExtractionProcessor<?>> processors = Arrays.asList(mockProcessor);
        factory = new DataExtractionProcessorFactory(processors);

        boolean result = factory.isSupported("parchment");

        assertTrue(result);
    }

    @Test
    void isSupported_WithNullType_ShouldReturnFalse() {
        DataExtractionProcessor<?> mockProcessor = mock(DataExtractionProcessor.class);
        List<DataExtractionProcessor<?>> processors = Arrays.asList(mockProcessor);
        factory = new DataExtractionProcessorFactory(processors);

        boolean result = factory.isSupported(null);

        assertFalse(result);
    }

    @Test
    void isSupported_WithEmptyType_ShouldReturnFalse() {
        DataExtractionProcessor<?> mockProcessor = mock(DataExtractionProcessor.class);
        List<DataExtractionProcessor<?>> processors = Arrays.asList(mockProcessor);
        factory = new DataExtractionProcessorFactory(processors);

        boolean result = factory.isSupported("");

        assertFalse(result);
    }

}
