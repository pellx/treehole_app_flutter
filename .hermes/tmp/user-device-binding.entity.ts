import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  Index,
} from 'typeorm';

@Entity('user_device_binding')
@Index('uk_user_device', ['user_id', 'device_id'], { unique: true })
export class UserDeviceBindingEntity {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'int' })
  user_id: number;

  @Index('idx_device_id')
  @Column({ type: 'int' })
  device_id: number;

  @Column({ type: 'varchar', length: 20, default: 'active' })
  status: string;

  @CreateDateColumn()
  bound_at: Date;

  @Column({ type: 'timestamp', nullable: true, default: null })
  unbind_requested_at: Date;

  @Column({ type: 'timestamp', nullable: true, default: null })
  unbound_at: Date;
}
