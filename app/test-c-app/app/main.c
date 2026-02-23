#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(void)
{
    printf("========================================\n");
    printf("   Whanos C Application Test\n");
    printf("========================================\n\n");

    printf("[TEST] Starting C application...\n");
    printf("[TEST] Compiler: GCC\n");
    printf("[TEST] Language: C\n");
    printf("[TEST] Build system: Makefile\n\n");

    // Test basic C features
    printf("[TEST] Testing basic C operations:\n");
    
    int a = 42;
    int b = 58;
    int sum = a + b;
    printf("  - Addition: %d + %d = %d\n", a, b, sum);
    
    int product = a * b;
    printf("  - Multiplication: %d * %d = %d\n", a, b, product);
    
    // Test string operations
    char message[] = "Hello from Whanos C!";
    printf("\n[TEST] String operations:\n");
    printf("  - Message: %s\n", message);
    printf("  - Length: %lu\n", strlen(message));
    
    // Test dynamic memory
    printf("\n[TEST] Dynamic memory allocation:\n");
    int *array = malloc(5 * sizeof(int));
    if (array == NULL) {
        fprintf(stderr, "[ERROR] Memory allocation failed\n");
        return 1;
    }
    
    for (int i = 0; i < 5; i++) {
        array[i] = i * 10;
        printf("  - array[%d] = %d\n", i, array[i]);
    }
    
    free(array);
    printf("  - Memory freed successfully\n");
    
    printf("\n[TEST] SUCCESS: All C tests passed!\n");
    printf("========================================\n");
    
    return 0;
}
