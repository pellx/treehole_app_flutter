import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  Index,
} from 'typeorm';

@Entity('user_identifier_history')
@Index('idx_user_id_type', ['user_id', 'type'])
export class UserIdentifierHistoryEntity {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'int' })
  user_id: number;

  @Column({ type: 'varchar', length: 20 })
  type: string;

  @Column({ type: 'varchar', length: 255, nullable: true, default: null })
  old_value: string;

  @CreateDateColumn()
  changed_at: Date;
}
