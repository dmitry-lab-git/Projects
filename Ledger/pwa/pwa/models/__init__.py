# pwa/models/__init__.py
from .base import metadata
from .dicts import (
    Account, Address, Contragent, Merchant, DictCategory, DictLedgerVersion,
    DictType, Entity, Responsible, DictStatus
)
from .transactions import (
    Transaction, AccBalanceSnapshotRegister, StagingTransaction
)
from .infrastructure import ResourceCatalog, MaterialDisposition, MeasuringDevice, DisposalPoint
from .medicine import SupplementCatalog, SupplementIntake, ObservationLog
from .projects import ProjectRegistry, ProjectMetadata

# Переименовываем переменные для совместимости со старым кодом
accounts_table = Account.__table__
addresses_table = Address.__table__
contragents_table = Contragent.__table__
dict_categories_table = DictCategory.__table__
dict_ledger_versions_table = DictLedgerVersion.__table__
dict_types_table = DictType.__table__
entities_table = Entity.__table__
responsibles_table = Responsible.__table__
dict_statuses_table = DictStatus.__table__

transaction_table = Transaction.__table__
acc_balance_snapshot_register = AccBalanceSnapshotRegister.__table__
staging_table = StagingTransaction.__table__
project_registry_table = ProjectRegistry.__table__
project_metadata_table = ProjectMetadata.__table__
