#include "ctors_dtors.c"

struct StaticObject {
    StaticObject();
    ~StaticObject();
};

StaticObject::StaticObject() {
    printf("hello StaticObject::StaticObject\n");
}

StaticObject::~StaticObject() {
    printf("hello StaticObject::~StaticObject\n");
}

static StaticObject static_object;
