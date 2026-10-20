"""
modules/common/legacy_rows.py
Read-side tolerance for legacy rows in response models: one old row must never turn a whole list into a 500.

1. NULLs from the startup schema upgrade. database/schema_upgrade_service.py (step 4b) adds a model column that
   only has a Python-side ``default=`` as a plain nullable column, so every row that existed before the upgrade
   reads NULL there. ``LegacyRowTolerantModel`` normalises those NULLs on read: a None in a field whose
   annotation does not accept None falls back to the field's declared default, else to the ORM column's scalar
   default. Money / rate fields (``float``) are never filled: declare them ``Optional[float]`` so a legacy NULL
   stays None instead of a fabricated 0.0 or 1.0. Fields with no default are left untouched (validation still
   reports them), so genuinely required data is never invented.

2. Input rules re-run on read. Response models usually inherit from the Create/Base schema, so its input-only
   rules (``Field(gt=0)``, ``min_length``, ``max_length``, ``pattern``, ``@field_validator`` checks such as
   "ACID is exactly 19 digits") are re-applied to stored rows. ``@read_model`` removes them from a response model
   (the Create/Update schemas keep them): field constraints, field validators inherited from the bases, and the
   same rules in nested models (replaced by constraint-free read variants). Validators declared on the response
   class itself are kept: they are read-side normalisers by definition. Model validators are kept.
"""
import copy
import types
from typing import Any, Dict, Set, Union, get_args, get_origin

from annotated_types import BaseMetadata
from pydantic import BaseModel, model_validator
from pydantic.fields import FieldInfo
from pydantic_core import PydanticUndefined
from sqlalchemy import inspect as sa_inspect
from sqlalchemy.exc import NoInspectionAvailable

_MISSING = object()


# ── 1. Legacy NULLs ──────────────────────────────────────────────────────────────────────────────────────────

def _accepts_none(annotation: Any) -> bool:
    if annotation is Any or annotation is None or annotation is type(None):
        return True
    if get_origin(annotation) in (Union, types.UnionType):
        return any(_accepts_none(arg) for arg in get_args(annotation))
    return False


def _orm_scalar_default(obj: Any, attr_name: str) -> Any:
    """Scalar ``Column(default=...)`` of ``attr_name`` on a mapped instance, or _MISSING (callables are skipped)."""
    try:
        mapper = sa_inspect(type(obj))
    except NoInspectionAvailable:
        return _MISSING
    column = mapper.columns.get(attr_name)
    default = getattr(column, "default", None) if column is not None else None
    if default is None or not getattr(default, "is_scalar", False):
        return _MISSING
    return default.arg


def _field_default(field: FieldInfo) -> Any:
    if field.default is not PydanticUndefined and field.default is not None:
        return copy.deepcopy(field.default)
    if field.default_factory is not None:
        return field.default_factory()
    return _MISSING


def legacy_null_fallback(field_name: str, field: FieldInfo, source: Any) -> Any:
    """Value to use instead of a legacy NULL in ``field_name``, or _MISSING when there is no safe fallback.
    Amounts and rates (``float``) never get one: a missing money value must not read as 0.0 or 1.0."""
    if field.annotation is float:
        return _MISSING
    value = _field_default(field)
    if value is _MISSING and not isinstance(source, dict):
        value = _orm_scalar_default(source, field_name)
    return value


class LegacyRowTolerantModel(BaseModel):
    """Response base: a legacy NULL in a non-nullable, non-money field reads as the declared (or ORM) default."""

    @model_validator(mode="before")
    @classmethod
    def _fill_legacy_nulls(cls, data: Any) -> Any:
        is_mapping = isinstance(data, dict)
        replacements: Dict[str, Any] = {}
        for name, field in cls.model_fields.items():
            if _accepts_none(field.annotation):
                continue
            current = data.get(name, _MISSING) if is_mapping else getattr(data, name, _MISSING)
            if current is not None:
                continue
            fallback = legacy_null_fallback(name, field, data)
            if fallback is not _MISSING:
                replacements[name] = fallback
        if not replacements:
            return data
        if is_mapping:
            return {**data, **replacements}
        # ORM instance: hand Pydantic a mapping with the same attributes plus the normalised values.
        out: Dict[str, Any] = {}
        for name in cls.model_fields:
            value = getattr(data, name, _MISSING)
            if value is not _MISSING:
                out[name] = value
        out.update(replacements)
        return out


# ── 2. Input rules on read ───────────────────────────────────────────────────────────────────────────────────

def _is_input_constraint(meta: Any) -> bool:
    """gt / ge / lt / le / min_length / max_length / multiple_of / strict (annotated_types) or a regex pattern."""
    return isinstance(meta, BaseMetadata) or getattr(meta, "pattern", None) is not None


def _has_input_rules(model: type, seen: Set[type]) -> bool:
    if model in seen:
        return False
    seen.add(model)
    if model.__pydantic_decorators__.field_validators:
        return True
    for field in model.model_fields.values():
        if any(_is_input_constraint(m) for m in field.metadata):
            return True
        if any(_has_input_rules(m, seen) for m in _models_in(field.annotation)):
            return True
    return False


def _models_in(annotation: Any):
    if isinstance(annotation, type) and issubclass(annotation, BaseModel):
        yield annotation
    for arg in get_args(annotation):
        yield from _models_in(arg)


_READ_VARIANTS: Dict[type, type] = {}


def _read_variant(model: type) -> type:
    """Constraint-free subclass of a nested model (the original keeps its rules for request bodies)."""
    if model not in _READ_VARIANTS:
        def _from_base(cls, data):
            if isinstance(data, model):
                return data.model_dump()
            return data

        attrs = {
            "__module__": model.__module__,
            "_from_base": model_validator(mode="before")(_from_base),
        }
        variant = type(f"{model.__name__}Read", (model,), attrs)
        _READ_VARIANTS[model] = read_model(variant)
    return _READ_VARIANTS[model]


def _swap_nested(annotation: Any) -> Any:
    if isinstance(annotation, type) and issubclass(annotation, BaseModel):
        return _read_variant(annotation) if _has_input_rules(annotation, set()) else annotation
    args = get_args(annotation)
    if not args:
        return annotation
    new_args = tuple(_swap_nested(a) for a in args)
    if new_args == args:
        return annotation
    origin = get_origin(annotation)
    if origin in (Union, types.UnionType):
        return Union[new_args]
    return origin[new_args if len(new_args) > 1 else new_args[0]]


def read_model(cls: type) -> type:
    """Class decorator for response models: drop input-only rules inherited from the Create/Base schema."""
    changed = False
    fields = cls.__pydantic_fields__
    for name, field in list(fields.items()):
        metadata = [m for m in field.metadata if not _is_input_constraint(m)]
        annotation = _swap_nested(field.annotation)
        if len(metadata) != len(field.metadata) or annotation is not field.annotation:
            relaxed = copy.copy(field)
            relaxed.metadata = metadata
            relaxed.annotation = annotation
            fields[name] = relaxed
            changed = True
    validators = cls.__pydantic_decorators__.field_validators
    for name in [n for n in validators if n not in cls.__dict__]:
        del validators[name]
        changed = True
    if changed:
        cls.model_rebuild(force=True)
    return cls


__all__ = ["LegacyRowTolerantModel", "legacy_null_fallback", "read_model"]
